# Local Meeting

Native macOS app for recording meetings or importing audio, transcribing offline, and extracting decisions, deliverables, actions, questions and blockers. No account, API key, remote inference or web server. Initial installation downloads public software/models; meeting processing is local with network denied by a macOS sandbox profile.

## Install on another Mac

Clone the public GitHub repository into a local folder outside iCloud/OneDrive/Dropbox, then run:

```sh
git clone https://github.com/adroiteck/local-meeting.git
cd local-meeting
./install.sh
open "$HOME/Applications/Local Meeting.app"
```

No GitHub authentication is required. You can also use GitHub **Code → Download ZIP**, extract it, open Terminal in that folder and run `bash install.sh`. Internet access is needed for the initial dependency/model downloads; meeting processing then runs offline.

Requirements: macOS 15+, Apple Silicon or Intel, Apple Command Line Tools, approximately 4 GB free installation space. Designed for an 8 GB Mac: Whisper Base English (~148 MB), Qwen2.5 1.5B Q4_K_M (~1.12 GB), two CPU threads for notes, models run sequentially. Actual 8 GB/Intel performance is not yet measured. English only in this initial profile. Small models can miss or misclassify commitments.

1. Copy this source folder to a local, non-synchronized location on the new Mac, or run `./package.sh` here and extract the source archive there. The source package excludes all meeting data and models.
2. Run `./install.sh`. If Command Line Tools are missing, complete Apple's installation prompt and rerun. No Homebrew, pip packages, Docker or global model service required. No sudo used by this project.
3. Run `open "$HOME/Applications/Local Meeting.app"`.
4. On the first explicit recording, allow microphone and (for remote meetings) Screen & System Audio Recording in System Settings > Privacy & Security. macOS may require relaunching the app. Mic-only mode needs only microphone permission.

The installer places the app in `~/Applications/Local Meeting.app` and records this source folder in its Info.plist. Keep the source folder in place; rerun installation after moving it. Runtime engines compile for the destination architecture. Use the source package, not another Mac's `.runtime` directory, when changing architectures.

## Use

Enter a title, then choose **Record meeting**. The default captures your microphone and all audible system audio separately; headphones help prevent duplicate remote speech. Avoid other sound-producing apps. Select **Microphone only** for in-person meetings. Select **Stop & process** to generate notes. **Import audio** accepts audio/video formats supported by Apple's AVFoundation (WAV, AIFF, M4A and supported MP4/MOV audio; not every codec/container).

Notes open in the default Markdown application. **Open meeting folder** shows all evidence. The app stores meetings under `~/Library/Application Support/Local Meeting/meetings`, outside the source folder:

- `notes.md`: draft notes grouped into decisions, deliverables, actions, questions, blockers and status points.
- `notes.json`: structured items and rejected evidence checks.
- `transcript.txt` and `transcript.json`: timestamped speech and stable segment references.
- Original/imported audio or microphone/system CAF tracks, converted WAVs, raw Whisper JSON.
- `ai-*.json`, `prompt-*.txt`, `engine.log`, `processing.log`: local troubleshooting evidence; these contain meeting content.
- `capture.json`: track timing and capture errors. Channels identify microphone vs system, not individual remote speakers.
- `provenance.json`: locked engine/model identity and completion time.

Every note needs a matching quote and segment ID. Owner/due strings absent from its cited text are replaced with `not specified`. These checks verify textual evidence, not semantic correctness: review the draft against the transcript. Suggestions can still be mistaken for commitments; speaker attribution and date interpretation are deliberately not inferred. No automatic calendar, task-system, email or document publishing.

A display must be available for remote system capture. No screen-image output is registered or saved. Connecting/disconnecting audio devices while recording is untested; stop first. Capture errors retain raw audio and fail processing. Sudden power loss may leave a partial CAF; try importing the retained file. Recordings are not auto-resumed.

## CLI / recovery

Run commands from the source folder (paths with spaces must be quoted):

```sh
./meeting.sh --meeting "$PWD/data/example" --audio "/absolute/path/recording.m4a"
./meeting.sh --meeting "$PWD/data/example-retry" --transcript "$PWD/data/example/transcript.json"
./install.sh --verify
/usr/bin/python3 -m unittest discover -s tests -v
./scripts/smoke.sh
```

A project-wide `.runtime/processing.lock` prevents concurrent model jobs. After a crash, check its PID and confirm no pipeline/engine is running before removing that lock directory. An explicit English blocker phrase classified as a decision is conservatively moved to blockers unless the quote also states a choice. Summary falls back to the first three supported notes if the model emits no overview. The UI keeps raw recording files if processing fails. Do not quit during capture/processing; the app asks you to stop and finish first. No automatic deletion or retention policy: delete individual meeting folders in Finder when no longer needed.

## Reproducibility and privacy

`lock.json` fixes engine Git commits, CMake archive and model revisions/SHA-256. Installer verifies hashes before use, builds static engines in `.runtime`, signs the local app ad hoc, and writes an installed-artifact manifest. `--verify` checks installed engine/app/helper/pipeline/profile hashes and model integrity. `./install.sh` is repeatable, reuses verified downloads and pinned source checkouts. Model checksums identify files, not guarantees about their output.

Apple's compiler, SDK, CLT-provided Python and OS frameworks come from the target Mac; they are **not bit-for-bit locked** across macOS versions. Install reproducibility means pinned app source, engines, models and build flags, with host toolchain recorded in the installation manifest; inference outputs can vary by hardware/framework versions. No claim of byte-identical builds.

Only the installer fetches from GitHub and Hugging Face. `meeting.sh` and the app's processing subprocess use `sandbox-exec` with `(deny network*)`; model inference cannot use the network. No telemetry code or cloud-provider fallback. The native capture UI has no networking code; this profile isolates processing, not the whole computer. `sandbox-exec` is an existing deprecated macOS tool, checked by the smoke test; future OS support is not guaranteed.

Files are created under a restrictive umask (folders 700, files 600), protected by the Mac account and disk security. This app does not add application-level encryption. Avoid iCloud/OneDrive/Dropbox/Git-synced locations, use FileVault per workplace policy, and obtain permission required by your employer/meeting participants. Models are public downloads; work content is never part of installation. The app does not modify login items, system services, meeting-platform settings or other projects. macOS permission grants are per-machine and cannot be reproduced automatically. Re-signing after source changes may require permissions again.

## Remove / update

Close the app. Remove `~/Applications/Local Meeting.app`, `.runtime` and `.cache` to uninstall the generated runtime. Meeting folders in `~/Library/Application Support/Local Meeting/meetings` (and any explicit CLI destination) remain until you separately delete them. A new source version or lock change requires rerunning `install.sh`; review lock changes before downloading. Do not copy private meeting data into source control or the source package.

Upstream components: [whisper.cpp](https://github.com/ggml-org/whisper.cpp), [llama.cpp](https://github.com/ggml-org/llama.cpp), [Qwen2.5-1.5B-Instruct-GGUF](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF), [Whisper models](https://huggingface.co/ggerganov/whisper.cpp), [CMake](https://cmake.org/). Respect upstream licenses; model/source distributions retain upstream licensing. Current build/test evidence is in `VALIDATION.md`.
