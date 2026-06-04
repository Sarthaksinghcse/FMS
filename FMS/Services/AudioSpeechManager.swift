import Foundation
import AVFoundation
import Combine

public final class AudioSpeechManager: ObservableObject {
    public static let shared = AudioSpeechManager()
    private let synthesizer = AVSpeechSynthesizer()
    
    private init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up AVAudioSession for speech: \(error)")
        }
    }
    
    public func speak(_ text: String) {
        // Stop currently speaking utterance if any
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
