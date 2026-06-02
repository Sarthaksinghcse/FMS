// FMS/Services/SOSSoundManager.swift

import AVFoundation

/// Singleton that keeps AVAudioPlayer alive outside SwiftUI's view lifecycle.
/// SwiftUI @State vars can be reset on re-renders, causing silent deallocation.
final class SOSSoundManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SOSSoundManager()

    private var player: AVAudioPlayer?
    private var isPlaying = false

    private override init() {
        super.init()
    }

    func playAlarm() {
        guard !isPlaying else { return }

        // Try bundle resource (works when file is in Copy Bundle Resources)
        let url: URL?
        if let bundleURL = Bundle.main.url(forResource: "fire_alarm", withExtension: "mp3") {
            url = bundleURL
            print("🔔 [SOSSoundManager] Found fire_alarm.mp3 in bundle.")
        } else {
            // Fallback: direct Components path (for Simulator runs without proper bundle inclusion)
            let fallback = Bundle.main.bundlePath + "/fire_alarm.mp3"
            url = FileManager.default.fileExists(atPath: fallback) ? URL(fileURLWithPath: fallback) : nil
            print("⚠️ [SOSSoundManager] Bundle lookup failed. Trying fallback path.")
        }

        guard let soundURL = url else {
            print("❌ [SOSSoundManager] fire_alarm.mp3 not found anywhere. Make sure it is added to Target > Build Phases > Copy Bundle Resources.")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.duckOthers]   // lower other audio, not mix — gives alarm priority
            )
            try AVAudioSession.sharedInstance().setActive(true)

            let p = try AVAudioPlayer(contentsOf: soundURL)
            p.delegate = self
            p.numberOfLoops = -1   // loop indefinitely until stopped
            p.volume = 1.0
            p.prepareToPlay()
            p.play()

            self.player = p
            self.isPlaying = true
            print("🔔 [SOSSoundManager] Alarm playing.")
        } catch {
            print("❌ [SOSSoundManager] Playback failed: \(error.localizedDescription)")
        }
    }

    func stopAlarm() {
        guard isPlaying else { return }
        player?.stop()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        print("🔕 [SOSSoundManager] Alarm stopped.")
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // numberOfLoops = -1 means this is never called unless manually stopped
        isPlaying = false
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ [SOSSoundManager] Decode error: \(error?.localizedDescription ?? "unknown")")
        isPlaying = false
    }
}
