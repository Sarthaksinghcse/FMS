//
//  DrowsinessOverlay.swift
//  FMS
//
//  SwiftUI overlay views for the drowsiness detection system.
//  - CameraPreviewPIP: small thumbnail of front camera (driver awareness)
//  - DrowsinessAlarmView: full-screen native SOS-style alarm when driver is asleep
//  - DrowsinessMonitorHUD: iOS native FaceTime-style PIP
//  Target: iOS 26+
//

import SwiftUI
import AVFoundation

// MARK: - Camera PIP (Picture-in-Picture thumbnail)

struct CameraPreviewPIP: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Native Slide To Resume Button
@available(iOS 26.0, *)
struct SlideToResumeButton: View {
    let action: () -> Void
    @State private var offset: CGFloat = 0
    let buttonWidth: CGFloat = 300
    let knobSize: CGFloat = 64
    
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.15))
            
            Text("slide to resume")
                .font(.system(size: 20 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .regular))
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity)
            
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: offset + knobSize)
            
            Circle()
                .fill(Color.white)
                .frame(width: knobSize, height: knobSize)
                .overlay(
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                        .foregroundColor(.black)
                )
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 && value.translation.width < buttonWidth - knobSize {
                                offset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if offset > buttonWidth - knobSize - 20 {
                                // Trigger haptic and action
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                action()
                                offset = 0
                            } else {
                                withAnimation(.spring()) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .frame(width: buttonWidth, height: knobSize)
    }
}


// MARK: - Full Screen Alarm View

@available(iOS 26.0, *)
struct DrowsinessAlarmView: View {
    @ObservedObject var detector: DrowsinessDetector
    @State private var flashOn = false
    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        ZStack {
            // Native dark glass background
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
            
            // Subtle red pulsing vignette
            RadialGradient(
                colors: [AppTheme.Status.danger.opacity(flashOn ? 0.8 : 0.0), .clear],
                center: .center,
                startRadius: 50,
                endRadius: UIScreen.main.bounds.height / 1.5
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Emergency SOS Style Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.Status.danger)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 16)

                // Native bold typography
                Text("Drowsiness Detected")
                    .font(.system(size: 34 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("It looks like your eyes were closed. Please pull over safely if you are tired.")
                    .font(.system(size: 17 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
                
                // Native slider
                SlideToResumeButton {
                    withAnimation(.spring(response: 0.4)) {
                        detector.dismissAlarm()
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                flashOn = true
            }
            // Trigger initial critical haptic
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

// MARK: - Monitoring HUD — Draggable FaceTime-style PIP

@available(iOS 26.0, *)
struct DrowsinessMonitorHUD: View {
    @ObservedObject var detector: DrowsinessDetector

    // Drag state
    @State private var position: CGPoint = CGPoint(x: 300, y: 120)
    @GestureState private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    // UI state
    @State private var isCollapsed = false
    @State private var expanded   = false

    private let pipW: CGFloat = 100 // Slightly wider for FaceTime aspect ratio
    private let pipH: CGFloat = 150
    private let collapsedSize: CGFloat = 38
    private let padding: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if isCollapsed {
                    // ── Collapsed: just a small eye badge ────────────────────
                    collapsedBadge
                        .position(clamp(position, in: geo.size, itemSize: CGSize(width: collapsedSize, height: collapsedSize)))
                        .offset(dragOffset)
                        .gesture(dragGesture(in: geo.size, itemSize: CGSize(width: collapsedSize, height: collapsedSize)))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35)) { isCollapsed = false }
                        }

                } else {
                    // ── Expanded: Pure FaceTime PIP ──────────────────────────────────
                    ZStack(alignment: .topTrailing) {
                        if let layer = detector.cameraPreviewLayer {
                            CameraPreviewPIP(previewLayer: layer)
                                .frame(width: expanded ? 140 : pipW,
                                       height: expanded ? 210 : pipH)
                                .clipShape(RoundedRectangle(cornerRadius: expanded ? 24 : 16, style: .continuous))
                                .shadow(color: .black.opacity(0.2), radius: 15, y: 8)
                        } else {
                            RoundedRectangle(cornerRadius: expanded ? 24 : 16, style: .continuous)
                                .fill(Color.black.opacity(0.6))
                                .frame(width: pipW, height: pipH)
                        }
                        
                        // Tiny native privacy-style indicator dot instead of a loud pill
                        if detector.state == .monitoring {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .padding(expanded ? 12 : 8)
                        } else if case .eyesClosed = detector.state {
                            // Yellow warning dot
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 8, height: 8)
                                .padding(expanded ? 12 : 8)
                        }
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { expanded.toggle() }
                    }
                    // Drag to move
                    .position(clamp(position, in: geo.size,
                                    itemSize: CGSize(width: expanded ? 140 : pipW,
                                                     height: expanded ? 210 : pipH)))
                    .offset(dragOffset)
                    .scaleEffect(isDragging ? 1.05 : 1.0)
                    .shadow(color: isDragging ? .black.opacity(0.3) : .clear, radius: 20, y: 10)
                    .gesture(
                        dragGesture(in: geo.size,
                                    itemSize: CGSize(width: expanded ? 140 : pipW,
                                                     height: expanded ? 210 : pipH))
                    )
                    .simultaneousGesture(
                        // Long-press to collapse to badge
                        LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.35)) { isCollapsed = true }
                        }
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: expanded)
                }
            }
            .onAppear {
                // Default: top-right corner with padding
                position = CGPoint(x: geo.size.width - pipW / 2 - padding,
                                   y: 120 + pipH / 2)
            }
        }
        .allowsHitTesting(true)
    }

    // MARK: - Collapsed Badge
    private var collapsedBadge: some View {
        ZStack {
            Circle()
                .fill(Color(UIColor.systemGray6))
                .frame(width: collapsedSize, height: collapsedSize)
                .shadow(color: .black.opacity(0.15), radius: 6)
            Image(systemName: "video.fill")
                .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                .foregroundStyle(Color(UIColor.label))
        }
    }

    // MARK: - Drag gesture with corner snapping
    private func dragGesture(in size: CGSize, itemSize: CGSize) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onChanged { _ in
                if !isDragging {
                    withAnimation(.easeOut(duration: 0.15)) { isDragging = true }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .onEnded { value in
                withAnimation(.easeOut(duration: 0.15)) { isDragging = false }
                // Apply translation
                let newX = position.x + value.translation.width
                let newY = position.y + value.translation.height
                // Snap to nearest corner
                let corners = corners(for: size, itemSize: itemSize)
                let nearest = corners.min(by: {
                    dist($0, CGPoint(x: newX, y: newY)) < dist($1, CGPoint(x: newX, y: newY))
                }) ?? corners[0]
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    position = nearest
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
    }

    // Four corner snap positions
    private func corners(for screenSize: CGSize, itemSize: CGSize) -> [CGPoint] {
        let hw = itemSize.width / 2 + padding
        let hh = itemSize.height / 2 + padding
        return [
            CGPoint(x: hw,                      y: 110 + hh),           // top-left
            CGPoint(x: screenSize.width - hw,   y: 110 + hh),           // top-right
            CGPoint(x: hw,                      y: screenSize.height - hh - 220), // bottom-left
            CGPoint(x: screenSize.width - hw,   y: screenSize.height - hh - 220)  // bottom-right
        ]
    }

    // Clamp position within screen bounds
    private func clamp(_ point: CGPoint, in size: CGSize, itemSize: CGSize) -> CGPoint {
        let hw = itemSize.width / 2 + padding
        let hh = itemSize.height / 2 + padding
        return CGPoint(
            x: max(hw, min(point.x + dragOffset.width, size.width - hw)),
            y: max(hh + 60, min(point.y + dragOffset.height, size.height - hh - 200))
        )
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}
