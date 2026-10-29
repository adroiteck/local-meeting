import AVFoundation
import Foundation

func le<T: FixedWidthInteger>(_ value: T) -> Data {
    var v = value.littleEndian
    return withUnsafeBytes(of: &v) { Data($0) }
}
func header(_ bytes: UInt32) -> Data {
    var d = Data("RIFF".utf8); d.append(le(bytes + 36)); d.append(Data("WAVEfmt ".utf8))
    d.append(le(UInt32(16))); d.append(le(UInt16(1))); d.append(le(UInt16(1)))
    d.append(le(UInt32(16000))); d.append(le(UInt32(32000))); d.append(le(UInt16(2))); d.append(le(UInt16(16)))
    d.append(Data("data".utf8)); d.append(le(bytes)); return d
}
do {
    guard CommandLine.arguments.count == 3 else { throw NSError(domain: "Usage: normalize INPUT OUTPUT.wav", code: 1) }
    let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
    guard let track = asset.tracks(withMediaType: .audio).first else { throw NSError(domain: "No audio track", code: 1) }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false])
    reader.add(output)
    let dest = URL(fileURLWithPath: CommandLine.arguments[2])
    FileManager.default.createFile(atPath: dest.path, contents: header(0))
    let handle = try FileHandle(forWritingTo: dest)
    defer { try? handle.close() }
    try handle.seekToEnd()
    guard reader.startReading() else { throw reader.error! }
    var size: UInt64 = 0
    while let sample = output.copyNextSampleBuffer() {
        guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
        let length = CMBlockBufferGetDataLength(block)
        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
        guard status == noErr else { throw NSError(domain: "Audio read error", code: Int(status)) }
        size += UInt64(length)
        guard size < UInt64(UInt32.max) - 36 else { throw NSError(domain: "Audio exceeds WAV size limit", code: 1) }
        try handle.write(contentsOf: data)
    }
    guard reader.status == .completed, size > 0 else { throw reader.error ?? NSError(domain: "Empty audio", code: 1) }
    try handle.seek(toOffset: 0); try handle.write(contentsOf: header(UInt32(size)))
} catch { fputs("Audio conversion failed: \(error)\n", stderr); exit(1) }
