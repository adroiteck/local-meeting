import hashlib, json, os, pathlib, platform, plistlib, shutil, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
RUNTIME = ROOT / '.runtime'
LOCK = json.loads((ROOT / 'lock.json').read_text())
os.umask(0o077)

def run(*args):
    subprocess.run([str(x) for x in args], check=True)

def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''): h.update(b)
    return h.hexdigest()

def fetch(spec, dest):
    if dest.exists() and digest(dest) == spec['sha256']: return
    part = dest.with_suffix(dest.suffix + '.part')
    run('/usr/bin/curl', '--fail', '--location', '--retry', '3', '--output', part, spec['url'])
    if digest(part) != spec['sha256']:
        part.unlink()
        raise RuntimeError('SHA-256 mismatch: ' + str(dest))
    part.replace(dest)

def main():
    if '--verify' in sys.argv:
        for spec in LOCK['models'].values():
            p = RUNTIME / 'models' / spec['filename']
            if not p.exists() or digest(p) != spec['sha256']: raise RuntimeError('Missing or modified model: ' + str(p))
        manifest = json.loads((RUNTIME / 'installed.json').read_text())
        if manifest['lock_sha256'] != digest(ROOT / 'lock.json'): raise RuntimeError('Install lock changed; rerun installer')
        for rel, sha in manifest['artifacts'].items():
            if digest(ROOT / rel) != sha: raise RuntimeError('Modified artifact: ' + rel)
        print('PASS: locked models and installed artifacts verified')
        return
    if (RUNTIME / 'processing.lock').exists(): raise RuntimeError('A meeting pipeline is running; finish it before installing')
    if subprocess.run(['/usr/bin/pgrep', '-x', 'LocalMeeting'], stdout=subprocess.DEVNULL).returncode == 0:
        raise RuntimeError('Close Local Meeting before installing')
    if int(platform.mac_ver()[0].split('.')[0]) < 15: raise RuntimeError('macOS 15+ required')
    for p in [RUNTIME, RUNTIME / 'models', RUNTIME / 'sources', ROOT / '.cache', ROOT / 'data']:
        p.mkdir(parents=True, exist_ok=True)
    cmake_archive = ROOT / '.cache/cmake.tar.gz'
    fetch(LOCK['cmake'], cmake_archive)
    cmake = RUNTIME / 'cmake-3.31.6-macos-universal/CMake.app/Contents/bin/cmake'
    if not cmake.exists(): run('/usr/bin/tar', '-xzf', cmake_archive, '-C', RUNTIME)
    for name, spec in LOCK['engines'].items():
        source = RUNTIME / 'sources' / name
        if not source.exists(): run('/usr/bin/git', 'init', source)
        current = subprocess.run(['/usr/bin/git', '-C', str(source), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
        if current != spec['commit']:
            run('/usr/bin/git', '-C', source, 'fetch', '--depth', '1', spec['repo'], spec['commit'])
            run('/usr/bin/git', '-C', source, 'checkout', '--detach', '--force', spec['commit'])
        elif subprocess.run(['/usr/bin/git', '-C', str(source), 'diff', '--quiet']).returncode:
            raise RuntimeError('Engine source was modified: ' + str(source))
        build = RUNTIME / ('build-' + name)
        run(cmake, '-S', source, '-B', build, '-DCMAKE_BUILD_TYPE=Release', '-DBUILD_SHARED_LIBS=OFF',
            '-DGGML_NATIVE=OFF', '-DGGML_METAL=ON', '-DGGML_METAL_EMBED_LIBRARY=ON',
            '-DLLAMA_CURL=OFF', '-DLLAMA_BUILD_TESTS=OFF', '-DWHISPER_BUILD_TESTS=OFF')
        run(cmake, '--build', build, '--config', 'Release', '--target', 'whisper-cli' if name == 'whisper' else 'llama-cli', '-j', '2')
    for spec in LOCK['models'].values(): fetch(spec, RUNTIME / 'models' / spec['filename'])
    app_bundle = pathlib.Path.home() / 'Applications/Local Meeting.app'
    app = app_bundle / 'Contents'
    (app / 'MacOS').mkdir(parents=True, exist_ok=True)
    info = plistlib.loads((ROOT / 'src/Info.plist').read_bytes())
    info['LocalMeetingRoot'] = str(ROOT)
    (app / 'Info.plist').write_bytes(plistlib.dumps(info))
    run('/usr/bin/xcrun', 'swiftc', '-O', '-swift-version', '5', '-target', platform.machine() + '-apple-macos15.0',
        '-parse-as-library', ROOT / 'src/Meeting.swift', '-o', app / 'MacOS/LocalMeeting')
    run('/usr/bin/xattr', '-cr', app_bundle)
    run('/usr/bin/codesign', '--force', '--sign', '-', app_bundle)
    run('/usr/bin/xcrun', 'swiftc', '-O', '-target', platform.machine() + '-apple-macos15.0',
        ROOT / 'src/Normalize.swift', '-o', RUNTIME / 'normalize')
    artifacts = {}
    for p in [app / 'MacOS/LocalMeeting', app / 'Info.plist', RUNTIME / 'normalize',
              RUNTIME / 'build-whisper/bin/whisper-cli', RUNTIME / 'build-llama/bin/llama-cli',
              ROOT / 'src/pipeline.py', ROOT / 'src/offline.sb']:
        artifacts[str(p)] = digest(p)
    (RUNTIME / 'installed.json').write_text(json.dumps({'lock_sha256': digest(ROOT / 'lock.json'),
        'artifacts': artifacts, 'machine': platform.machine(), 'macos': platform.mac_ver()[0],
        'swift': subprocess.check_output(['/usr/bin/xcrun','swiftc','--version'], text=True),
        'sdk': subprocess.check_output(['/usr/bin/xcrun','--show-sdk-version'], text=True).strip(),
        'python': sys.version}, indent=2))
    print('\nInstalled. Open: ' + str(app_bundle))
    print('Runtime is offline. First recording requires macOS microphone and system-audio permission.')

if __name__ == '__main__':
    try: main()
    except Exception as e: print('INSTALL FAILED: ' + str(e), file=sys.stderr); sys.exit(1)
