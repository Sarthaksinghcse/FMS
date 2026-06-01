//
//  DrowsinessDetector.swift
//  FMS
//
//  Real-time driver drowsiness detection using AVFoundation + Vision.
//  - Captures front-camera frames at ~10 fps (battery-friendly)
//  - Detects eye landmarks via VNDetectFaceLandmarksRequest
//  - Calculates Eye Aspect Ratio (EAR) per frame
//  - If EAR stays below threshold for 5 continuous seconds → alarm
//  Target: iOS 26+
//

import AVFoundation
import Vision
import UIKit
import Combine
import AudioToolbox

// MARK: - Detection State

enum DrowsinessState: Equatable {
    case inactive                 // monitoring not running
    case monitoring               // eyes open — all clear
    case eyesClosed(Int)          // eyes closed — Int = consecutive seconds
    case noFace                   // face not detectable (sunglasses / bad angle)
    case alarm                    // 5 s threshold breached — WAKE UP
}

// MARK: - Drowsiness Detector

/// Not @MainActor at class level so AVCapture delegate (nonisolated) can use
/// the Vision handler freely. All UI-facing state updates are dispatched to @MainActor.
final class DrowsinessDetector: NSObject, ObservableObject {

    // MARK: Published state (always set on main thread)
    @Published @MainActor var state: DrowsinessState = .inactive
    @Published @MainActor var cameraPreviewLayer: AVCaptureVideoPreviewLayer?

    // MARK: Config
    var earThreshold: Double = 0.22   // EAR below this → eyes "closed"
    var alarmSeconds: Int    = 5      // consecutive closed-seconds before alarm

    // MARK: Guard: prevent double-start
    private var isSessionRunning = false

    // MARK: Private AV — not main-actor-isolated
    private let session      = AVCaptureSession()
    private let videoOutput  = AVCaptureVideoDataOutput()
    private let captureQueue = DispatchQueue(label: "fms.drowsiness.capture", qos: .userInteractive)

    // MARK: Private Vision — used only on captureQueue
    private let sequenceHandler = VNSequenceRequestHandler()

    // MARK: Counters — written from captureQueue, protected by serial queue
    private var closedFrames    = 0   // frames with EAR < threshold this second
    private var detectedFrames  = 0   // frames where a face was detected this second
    private var closedSeconds   = 0   // consecutive seconds where eyes were closed

    // MARK: Timers — main thread
    private var secondTimer: Timer?

    // MARK: - Start / Stop  (call from any context; dispatch internally)

    func start() {
        guard !isSessionRunning else { return }
        requestCameraAccess { [weak self] granted in
            guard granted, let self, !self.isSessionRunning else { return }
            self.isSessionRunning = true
            self.setupSession()
            Task { @MainActor [weak self] in
                self?.state = .monitoring
            }
        }
    }

    func stop() {
        isSessionRunning = false
        captureQueue.async { [weak self] in self?.session.stopRunning() }
        stopSecondTimer()
        Task { @MainActor [weak self] in
            self?.state = .inactive
        }
        closedFrames   = 0
        detectedFrames = 0
        closedSeconds  = 0
        stopAudio()
    }

    @MainActor func dismissAlarm() {
        stopAudio()
        closedFrames   = 0
        detectedFrames = 0
        closedSeconds  = 0
        state = .monitoring
        startSecondTimer()
    }

    // MARK: - Private Setup

    private func setupSession() {
        captureQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            
            // Use low resolution to drastically reduce Vision CPU load & prevent lagging
            self.session.sessionPreset = .cif352x288

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                let input  = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else { self.session.commitConfiguration(); return }
            self.session.addInput(input)

            self.videoOutput.setSampleBufferDelegate(self, queue: self.captureQueue)
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            guard self.session.canAddOutput(self.videoOutput) else { self.session.commitConfiguration(); return }
            self.session.addOutput(self.videoOutput)

            // Throttle to 10 fps — enough for EAR, saves battery
            try? device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 10)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 10)
            device.unlockForConfiguration()

            self.session.commitConfiguration()

            // Build preview layer on main thread
            let previewSession = self.session
            Task { @MainActor [weak self] in
                let layer = AVCaptureVideoPreviewLayer(session: previewSession)
                layer.videoGravity = .resizeAspectFill
                self?.cameraPreviewLayer = layer
                self?.startSecondTimer()
            }

            self.session.startRunning()
        }
    }

    private func startSecondTimer() {
        stopSecondTimer()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.secondTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.tickSecond()
            }
        }
    }

    private func stopSecondTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.secondTimer?.invalidate()
            self?.secondTimer = nil
        }
    }

    @MainActor private func tickSecond() {
        guard state != .alarm && state != .inactive else { return }

        let detected = detectedFrames
        let closed   = closedFrames
        detectedFrames = 0
        closedFrames   = 0

        if detected == 0 {
            // Vision saw no face at all this second
            closedSeconds = 0
            state = .noFace
        } else if closed > 5 {
            // More than half the frames this second had eyes closed
            closedSeconds += 1
            state = .eyesClosed(closedSeconds)
            if closedSeconds >= alarmSeconds {
                triggerAlarm()
            }
        } else {
            // Face detected, eyes open
            closedSeconds = 0
            state = .monitoring
        }
    }

    private func requestCameraAccess(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    completion(true)
        case .notDetermined: AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        default:             completion(false)
        }
    }

    // MARK: - Alarm

    @MainActor private func triggerAlarm() {
        guard state != .alarm else { return }
        state = .alarm
        stopSecondTimer()
        playAlarm()
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func playAlarm() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        repeatBeep()
    }

    private func repeatBeep() {
        AudioServicesPlaySystemSound(1005)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            Task { @MainActor [weak self] in
                guard self?.state == .alarm else { return }
                self?.repeatBeep()
            }
        }
    }

    private func stopAudio() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension DrowsinessDetector: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceLandmarksRequest { [weak self] req, _ in
            guard let self else { return }
            guard
                let results  = req.results as? [VNFaceObservation],
                let face     = results.first,
                let landmarks = face.landmarks
            else { return }

            // Prevent false positives: if head is turned significantly away, ignore EAR.
            // Relaxed to 0.8 radians (~45 deg). Pitch removed to allow looking down.
            let isHeadTurned = abs(face.yaw?.doubleValue ?? 0) > 0.8

            let leftEAR  = eyeAspectRatio(region: landmarks.leftEye,  box: face.boundingBox)
            let rightEAR = eyeAspectRatio(region: landmarks.rightEye, box: face.boundingBox)
            let avgEAR   = (leftEAR + rightEAR) / 2.0

            Task { @MainActor [weak self] in
                guard let self, self.state != .alarm else { return }
                // A face was visible this frame
                self.detectedFrames += 1
                if !isHeadTurned && avgEAR < self.earThreshold {
                    self.closedFrames += 1
                }
            }
        }

        try? sequenceHandler.perform([request], on: pixelBuffer, orientation: .leftMirrored)
    }
}

// MARK: - Pure EAR Helpers (free functions — no actor isolation needed)

/// Eye Aspect Ratio = (||p1-p5|| + ||p2-p4||) / (2 × ||p0-p3||)
private func eyeAspectRatio(region: VNFaceLandmarkRegion2D?, box: CGRect) -> Double {
    guard let region, region.pointCount >= 6 else { return 1.0 }
    let pts = region.normalizedPoints.map { p in
        CGPoint(x: box.origin.x + p.x * box.width,
                y: box.origin.y + p.y * box.height)
    }
    let a = euclidean(pts[1], pts[5])
    let b = euclidean(pts[2], pts[4])
    let c = euclidean(pts[0], pts[3])
    guard c > 0 else { return 1.0 }
    return (a + b) / (2.0 * c)
}

private func euclidean(_ a: CGPoint, _ b: CGPoint) -> Double {
    let dx = a.x - b.x; let dy = a.y - b.y
    return sqrt(dx * dx + dy * dy)
}
