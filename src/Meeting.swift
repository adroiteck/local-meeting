import SwiftUI
import ScreenCaptureKit
import AVFoundation
import CoreMedia
import UniformTypeIdentifiers

final class Capture: NSObject, SCStreamOutput, SCStreamDelegate {
    var stream: SCStream?
    var micEngine: AVAudioEngine?
    let queue = DispatchQueue(label: "localmeeting.audio")
    var files: [String: AVAudioFile] = [:]
    var starts: [String: Double] = [:]
    var failure: String?
    var expectedChannels: [String] = []
    var folder: URL!
    func start(folder: URL, microphoneOnly: Bool) async throws {
        self.folder = folder
        expectedChannels = microphoneOnly ? ["microphone"] : ["microphone", "system"]
        guard await AVCaptureDevice.requestAccess(for: .audio) else { throw NSError(domain: "Microphone permission denied. Enable it in System Settings > Privacy & Security.", code: 1) }
        if microphoneOnly {
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw NSError(domain: "No microphone input available", code: 1) }
            files["microphone"] = try AVAudioFile(forWriting: folder.appendingPathComponent("microphone.caf"), settings: format.settings,
                commonFormat: format.commonFormat, interleaved: format.isInterleaved)
            input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
                self.queue.sync {
                    do { try self.files["microphone"]?.write(from: buffer) }
                    catch { self.failure = error.localizedDescription }
                }
            }
            micEngine = engine
            try engine.start()
            return
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw NSError(domain: "No display available for system audio capture", code: 1) }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = 2; config.height = 2; config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.capturesAudio = !microphoneOnly
        config.captureMicrophone = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000; config.channelCount = 1
        let s = SCStream(filter: filter, configuration: config, delegate: self)
        if !microphoneOnly { try s.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue) }
        try s.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
        stream = s
        try await s.startCapture()
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        queue.async { self.failure = "Capture stopped: \(error.localizedDescription)" }
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sample.isValid, type == .audio || type == .microphone else { return }
        let key = type == .microphone ? "microphone" : "system"
        guard let desc = CMSampleBufferGetFormatDescription(sample),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc),
              let format = AVAudioFormat(streamDescription: asbd) else { return }
        let capacity = 4096
        let raw = UnsafeMutableRawPointer.allocate(byteCount: capacity, alignment: 16)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        var block: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sample, bufferListSizeNeededOut: nil,
            bufferListOut: list, bufferListSize: capacity, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment), blockBufferOut: &block)
        guard status == noErr, let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: list, deallocator: nil) else {
            failure = "Could not decode captured audio"; return
        }
        do {
            if files[key] == nil {
                files[key] = try AVAudioFile(forWriting: folder.appendingPathComponent(key + ".caf"), settings: format.settings,
                                             commonFormat: format.commonFormat, interleaved: format.isInterleaved)
                starts[key] = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
            }
            let file = files[key]!
            let elapsed = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample)) - starts[key]!
            if elapsed.isFinite && elapsed >= 0 {
                let expected = AVAudioFramePosition(elapsed * format.sampleRate)
                // Preserve capture gaps so later transcript timestamps do not drift.
                while expected - file.framePosition > 512 {
                    let count = AVAudioFrameCount(min(4096, expected - file.framePosition))
                    guard let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { break }
                    silence.frameLength = count
                    for entry in UnsafeMutableAudioBufferListPointer(silence.mutableAudioBufferList) {
                        if let data = entry.mData { memset(data, 0, Int(entry.mDataByteSize)) }
                    }
                    try file.write(from: silence)
                }
            }
            try file.write(from: buffer)
        } catch { failure = error.localizedDescription }
    }
    func stop() async throws {
        if let engine = micEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop(); micEngine = nil
        }
        do { try await stream?.stopCapture() }
        catch { queue.sync { failure = error.localizedDescription } }
        stream = nil
        queue.sync { files.removeAll() }
        let metadata: [String: Any] = queue.sync { ["starts": starts, "expected_channels": expectedChannels, "capture_error": failure ?? ""] }
        try JSONSerialization.data(withJSONObject: metadata).write(to: folder.appendingPathComponent("capture.json"))
        if let problem = queue.sync(execute: { failure }) { throw NSError(domain: problem, code: 1) }
    }
}

@MainActor final class Model: ObservableObject {
    @Published var status = "Ready — all processing stays on this Mac."
    @Published var recording = false
    @Published var busy = false
    @Published var microphoneOnly = false
    @Published var title = "Meeting"
    @Published var current: URL?
    var capture: Capture?
    var process: Process?
    let root = URL(fileURLWithPath: Bundle.main.object(forInfoDictionaryKey: "LocalMeetingRoot") as! String)
    let dataRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Local Meeting/meetings")
    func folder() throws -> URL {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let safe = title.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }.joined().prefix(60)
        let url = dataRoot.appendingPathComponent("\(formatter.string(from: Date()))-\(safe)-\(UUID().uuidString.prefix(6))")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        current = url; return url
    }
    func record() {
        busy = true; status = "Requesting recording permissions…"
        Task {
            do {
                let dest = try folder(); let c = Capture(); capture = c
                try await c.start(folder: dest, microphoneOnly: microphoneOnly)
                recording = true; status = "● Recording locally. Stop to transcribe and extract tasks."
            } catch { status = "Recording failed: \(error.localizedDescription)"; capture = nil }
            busy = false
        }
    }
    func stop() {
        busy = true
        Task {
            do { try await capture?.stop(); recording = false; capture = nil; analyze([]) }
            catch { recording = false; busy = false; status = "Capture failed; raw files retained. \(error.localizedDescription)" }
        }
    }
    func importAudio() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.audio, .movie]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do { _ = try folder(); analyze(["--audio", url.path]) }
            catch { status = error.localizedDescription }
        }
    }
    func analyze(_ extra: [String]) {
        guard let dest = current else { return }
        busy = true; status = "Processing locally… Models run sequentially. See processing.log in the meeting folder."
        let p = Process(); process = p
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
        p.arguments = ["-f", root.appendingPathComponent("src/offline.sb").path, "/usr/bin/python3",
                       root.appendingPathComponent("src/pipeline.py").path, "--meeting", dest.path] + extra
        let log = dest.appendingPathComponent("processing.log")
        FileManager.default.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600])
        do {
            let handle = try FileHandle(forWritingTo: log)
            p.standardOutput = handle; p.standardError = handle
            p.terminationHandler = { proc in
                try? handle.close()
                Task { @MainActor in
                    self.busy = false; self.process = nil
                    self.status = proc.terminationStatus == 0 ? "Done. Open notes to review the summary, deliverables and action items." : "Processing failed. Transcript/raw audio retained; inspect processing.log."
                    if proc.terminationStatus == 0 { NSWorkspace.shared.open(dest.appendingPathComponent("notes.md")) }
                }
            }
            try p.run()
        } catch { busy = false; status = "Processing failed: \(error.localizedDescription)" }
    }
}

@main struct MeetingApp: App {
    init() { umask(0o077) }
    @StateObject var model = Model()
    var body: some Scene {
        WindowGroup("Local Meeting") {
            VStack(alignment: .leading, spacing: 18) {
                Text("Local Meeting").font(.largeTitle.bold())
                Text("Record → Transcribe → Decisions, deliverables & action items").foregroundStyle(.secondary)
                TextField("Meeting title", text: $model.title).textFieldStyle(.roundedBorder).disabled(model.busy || model.recording)
                Toggle("Microphone only (in-person meeting)", isOn: $model.microphoneOnly).disabled(model.busy || model.recording)
                HStack {
                    Button(model.recording ? "Stop & process" : "Record meeting") { model.recording ? model.stop() : model.record() }
                        .disabled(model.busy).keyboardShortcut("r")
                    Button("Import audio…") { model.importAudio() }.disabled(model.busy || model.recording)
                    if model.busy { ProgressView().controlSize(.small) }
                }
                Text(model.status).textSelection(.enabled).frame(minHeight: 55, alignment: .topLeading)
                HStack {
                    Button("Open meeting folder") { if let url = model.current { NSWorkspace.shared.open(url) } }.disabled(model.current == nil)
                    Button("All meetings") { try? FileManager.default.createDirectory(at: model.dataRoot, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]); NSWorkspace.shared.open(model.dataRoot) }
                }
                Text("Offline • No account • No cloud APIs\nReview AI notes against the transcript. Owners and dates may be unspecified.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(28).frame(width: 570)
        }.windowResizability(.contentSize)
        .commands { CommandGroup(replacing: .appTermination) {
            Button("Quit Local Meeting") {
                if model.recording || model.busy {
                    let alert = NSAlert(); alert.messageText = "A meeting is recording or processing."
                    alert.informativeText = "Stop recording and let processing finish before quitting. Raw files remain in the meeting folder."
                    alert.runModal()
                } else { NSApplication.shared.terminate(nil) }
            }.keyboardShortcut("q")
        } }
    }
}
