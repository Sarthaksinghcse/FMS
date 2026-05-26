








import Foundation
import Speech
import NaturalLanguage
import AVFoundation


public struct ParsedTripData {
    public var startTime: String?
    public var endTime: String?
    public var startLocation: String?
    public var endLocation: String?
    public var mileage: Double?
}

@Observable
public final class VoiceTripLogger {
    
    
    
    public var isRecording = false
    public var transcribedText = ""
    public var parsedData: ParsedTripData?
    public var errorMessage: String?
    
    
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    public init() {}
    
    
    
    
    public func requestPermissions() async -> Bool {
        
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        
        let micAuthorized = await AVAudioApplication.requestRecordPermission()
        
        return speechAuthorized && micAuthorized
    }
    
    
    
    
    public func startRecording() async {
        
        guard await requestPermissions() else {
            self.errorMessage = "Microphone or Speech Recognition permissions denied. Please enable them in Settings."
            return
        }
        
        
        self.transcribedText = ""
        self.parsedData = nil
        self.errorMessage = nil
        
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
            return
        }
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest, let speechRecognizer = speechRecognizer else {
            self.errorMessage = "Speech recognizer is not available for this locale."
            return
        }
        
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            self.isRecording = true
        } catch {
            self.errorMessage = "Audio Engine failed to start: \(error.localizedDescription)"
            return
        }
        
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
            }
            
            
            if error != nil || result?.isFinal == true {
                self.stopRecording()
            }
        }
    }
    
    
    public func stopRecording() {
        guard isRecording else { return }
        
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        isRecording = false
        
        
        Task {
            await self.parseTranscription()
        }
    }
    
    
    
    
    private func parseTranscription() async {
        let text = self.transcribedText
        guard !text.isEmpty else { return }
        
        var data = ParsedTripData()
        
        
        
        let mileageRegex = /(?<value>\d+(?:\.\d+)?)\s*(?:miles|mi|km|kilometers)/.ignoresCase()
        if let match = try? mileageRegex.firstMatch(in: text) {
            data.mileage = Double(match.value)
        }
        
        
        
        let timeRegex = /(?<time>(?:1[0-2]|0?[1-9])(?::[0-5][0-9])?\s*(?:AM|PM|am|pm))/.ignoresCase()
        let timeMatches = text.matches(of: timeRegex)
        
        if timeMatches.count >= 1 {
            data.startTime = String(timeMatches[0].time).uppercased()
        }
        if timeMatches.count >= 2 {
            data.endTime = String(timeMatches[1].time).uppercased()
        }
        
        
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        
        var places: [String] = []
        let range = text.startIndex..<text.endIndex
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if tag == .placeName {
                places.append(String(text[tokenRange]))
            }
            return true
        }
        
        
        
        if places.count >= 1 {
            data.startLocation = places[0]
        }
        if places.count >= 2 {
            data.endLocation = places.last
        }
        
        
        if places.isEmpty {
            let lowerText = text.lowercased()
            if let fromRange = lowerText.range(of: "from "),
               let toRange = lowerText.range(of: " to ", range: fromRange.upperBound..<lowerText.endIndex) {
                
                let startLoc = text[fromRange.upperBound..<toRange.lowerBound].trimmingCharacters(in: .whitespaces)
                let endLoc = text[toRange.upperBound..<text.endIndex].trimmingCharacters(in: .whitespaces)
                
                
                let cleanEndLoc = String(endLoc.split(separator: " ").prefix(2).joined(separator: " "))
                
                data.startLocation = startLoc.capitalized
                data.endLocation = cleanEndLoc.capitalized
            }
        }
        
        self.parsedData = data
    }
}
