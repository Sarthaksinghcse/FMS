//
//  VoiceTripLogger.swift
//  FMS
//
//  Handles microphone audio recording, live transcription using the Speech framework,
//  and NaturalLanguage/Regex-based parsing for start/end times, locations, and mileage.
//  Target: iOS 26+ (requires iOS 17+ for @Observable & SwiftRegex).
//

import Foundation
import Speech
import NaturalLanguage
import AVFoundation

/// Structured data extracted from a voice log.
public struct ParsedTripData {
    public var startTime: String?
    public var endTime: String?
    public var startLocation: String?
    public var endLocation: String?
    public var mileage: Double?
}

@Observable
public final class VoiceTripLogger {
    
    // MARK: - Published State
    
    public var isRecording = false
    public var transcribedText = ""
    public var parsedData: ParsedTripData?
    public var errorMessage: String?
    
    // MARK: - Private Core Audio/Speech Properties
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Use the default locale, or explicitly "en-US" depending on region requirements
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    public init() {}
    
    // MARK: - Permissions
    
    /// Requests both Microphone and Speech Recognition permissions.
    public func requestPermissions() async -> Bool {
        // 1. Request Speech Authorization
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        // 2. Request Microphone Authorization (async iOS 17+ API)
        let micAuthorized = await AVAudioApplication.requestRecordPermission()
        
        return speechAuthorized && micAuthorized
    }
    
    // MARK: - Recording & Transcription
    
    /// Starts the audio engine and begins live transcription.
    public func startRecording() async {
        // Guarantee permissions first
        guard await requestPermissions() else {
            self.errorMessage = "Microphone or Speech Recognition permissions denied. Please enable them in Settings."
            return
        }
        
        // Reset previous state
        self.transcribedText = ""
        self.parsedData = nil
        self.errorMessage = nil
        
        // Setup Audio Session
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
        
        // Force speech recognition to report partial updates
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap to capture audio buffer
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
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
            }
            
            // If there's an error or the result is final, stop recording cleanly
            if error != nil || result?.isFinal == true {
                self.stopRecording()
            }
        }
    }
    
    /// Stops recording, tears down the audio tap to prevent memory leaks, and fires off parsing.
    public func stopRecording() {
        guard isRecording else { return }
        
        // Stop audio engine & safely remove the tap
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // Terminate request and task
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Nullify references to ensure 0 memory leaks
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        isRecording = false
        
        // Process the final text asynchronously
        Task {
            await self.parseTranscription()
        }
    }
    
    // MARK: - Parsing Logic
    
    /// Parses the transcribed text for times, locations, and mileage.
    private func parseTranscription() async {
        let text = self.transcribedText
        guard !text.isEmpty else { return }
        
        var data = ParsedTripData()
        
        // 1. Extract Mileage using Swift Regex DSL
        // Matches e.g. "14.5 miles", "12 km", "40 kilometers"
        let mileageRegex = /(?<value>\d+(?:\.\d+)?)\s*(?:miles|mi|km|kilometers)/.ignoresCase()
        if let match = try? mileageRegex.firstMatch(in: text) {
            data.mileage = Double(match.value)
        }
        
        // 2. Extract Times using Regex
        // Matches e.g. "10:30 AM", "4 PM", "08:15 am"
        let timeRegex = /(?<time>(?:1[0-2]|0?[1-9])(?::[0-5][0-9])?\s*(?:AM|PM|am|pm))/.ignoresCase()
        let timeMatches = text.matches(of: timeRegex)
        
        if timeMatches.count >= 1 {
            data.startTime = String(timeMatches[0].time).uppercased()
        }
        if timeMatches.count >= 2 {
            data.endTime = String(timeMatches[1].time).uppercased()
        }
        
        // 3. Extract Locations using NaturalLanguage (NLTagger)
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
        
        // Basic assignment: First mentioned place is origin, second is destination.
        // (A more advanced implementation could parse "from [X] to [Y]" contextually).
        if places.count >= 1 {
            data.startLocation = places[0]
        }
        if places.count >= 2 {
            data.endLocation = places.last
        }
        
        // Fallback rule-based parsing if NLTagger fails to detect cities
        if places.isEmpty {
            let lowerText = text.lowercased()
            if let fromRange = lowerText.range(of: "from "),
               let toRange = lowerText.range(of: " to ", range: fromRange.upperBound..<lowerText.endIndex) {
                
                let startLoc = text[fromRange.upperBound..<toRange.lowerBound].trimmingCharacters(in: .whitespaces)
                let endLoc = text[toRange.upperBound..<text.endIndex].trimmingCharacters(in: .whitespaces)
                
                // Cleanup endLoc (remove any trailing mileage or times if they got grouped)
                let cleanEndLoc = String(endLoc.split(separator: " ").prefix(2).joined(separator: " "))
                
                data.startLocation = startLoc.capitalized
                data.endLocation = cleanEndLoc.capitalized
            }
        }
        
        self.parsedData = data
    }
}
