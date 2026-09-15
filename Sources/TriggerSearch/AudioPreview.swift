import AVFoundation
import Foundation

/// Plays WAV/AIFF one-shots for auditioning. Trigger `.tci` files are not playable.
@MainActor
final class AudioPreview: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingPath: String?
    private var player: AVAudioPlayer?

    func play(_ url: URL) {
        stop()
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.delegate = self
        self.player = player
        playingPath = url.path
        player.play()
    }

    func stop() {
        player?.stop()
        player = nil
        playingPath = nil
    }

    func toggle(_ url: URL) {
        if playingPath == url.path { stop() } else { play(url) }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if self.player === player { self.player = nil; self.playingPath = nil }
        }
    }
}

/// Basic format facts for a one-shot, read on demand.
struct AudioInfo {
    var duration: TimeInterval
    var sampleRate: Double
    var channels: Int
    var bitDepth: Int?

    static func read(_ url: URL) -> AudioInfo? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.fileFormat
        let bits = (format.settings[AVLinearPCMBitDepthKey] as? Int)
        return AudioInfo(duration: Double(file.length) / format.sampleRate,
                         sampleRate: format.sampleRate,
                         channels: Int(format.channelCount),
                         bitDepth: bits)
    }

    var summary: String {
        var parts = [String(format: "%.2f s", duration),
                     String(format: "%g kHz", sampleRate / 1000),
                     channels == 1 ? "mono" : channels == 2 ? "stereo" : "\(channels) ch"]
        if let bitDepth { parts.append("\(bitDepth)-bit") }
        return parts.joined(separator: " · ")
    }
}
