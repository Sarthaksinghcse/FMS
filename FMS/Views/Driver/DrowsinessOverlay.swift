//
//  DrowsinessOverlay.swift
//  FMS
//
//  SwiftUI overlay views for the drowsiness detection system.
//  - CameraPreviewPIP: small thumbnail of front camera (driver awareness)
//  - DrowsinessStatusPill: monitoring / warning status indicator
//  - DrowsinessAlarmView: full-screen red alarm when driver is asleep
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

// MARK: - Status Pill

@available(iOS 26.0, *)
struct DrowsinessStatusPill: View {
    let state: DrowsinessState

    private var icon: String {
        switch state {
        case .inactive:        return "eye.slash"
        case .monitoring:      return "eye.fill"
        case .eyesClosed:      return "exclamationmark.triangle.fill"
        case .noFace:          return "person.fill.questionmark"
        case .alarm:           return "exclamationmark.octagon.fill"
        }
    }

    private var label: String {
        switch state {
        case .inactive:              return "Monitor Off"
        case .monitoring:            return "Monitoring"
        case .eyesClosed(let s):     return "Eyes Closed \(s)s"
        case .noFace:                return "Face Not Found"
        case .alarm:                 return "WAKE UP!"
        }
    }

    private var pillColor: Color {
        switch state {
        case .inactive:      return Color.fmsIndigo.opacity(0.4)
        case .monitoring:    return AppTheme.Status.success
        case .eyesClosed:    return AppTheme.Status.warning
        case .noFace:        return Color.fmsIndigo.opacity(0.2)
        case .alarm:         return AppTheme.Status.danger
        }
    }

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .scaleEffect(pulse && state == .alarm ? 1.3 : 1.0)
            Text(label)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(pillColor.opacity(0.92), in: Capsule())
        .shadow(color: pillColor.opacity(0.4), radius: 6, y: 2)
        .onChange(of: state) { _, new in
            if new == .alarm {
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                pulse = false
            }
        }
    }
}

// MARK: - Full Screen Alarm View

@available(iOS 26.0, *)
struct DrowsinessAlarmView: View {
    @ObservedObject var detector: DrowsinessDetector
    @State private var flashOn      = false
    @State private var textScale    = 1.0
    @State private var eyeScale     = 1.0

    var body: some View {
        ZStack {
            // Flashing red background
            Color.black.ignoresSafeArea()

            Rectangle()
                .fill(AppTheme.Status.danger.opacity(flashOn ? 0.55 : 0.25))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: flashOn)

            VStack(spacing: 32) {
                Spacer()

                // Animated eye icon
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(AppTheme.Status.danger.opacity(0.2 - Double(i) * 0.06), lineWidth: 2)
                            .frame(width: 130 + CGFloat(i) * 32,
                                   height: 130 + CGFloat(i) * 32)
                            .scaleEffect(eyeScale)
                    }
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppTheme.Status.danger.opacity(0.6), AppTheme.Status.danger.opacity(0.15)],
                                center: .center,
                                startRadius: 10, endRadius: 65
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse)
                }

                VStack(spacing: 12) {
                    Text("⚠️ DROWSINESS DETECTED")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .tracking(2)
                        .scaleEffect(textScale)

                    Text("Your eyes were closed for 5+ seconds")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.80))
                        .multilineTextAlignment(.center)

                    Text("Pull over safely at the nearest stop.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.60))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // Wake-up confirm button
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        detector.dismissAlarm()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.wave.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("I'm Awake — Resume")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.Status.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .white.opacity(0.25), radius: 12, y: 4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
                flashOn = true
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                eyeScale = 1.10
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).repeatForever(autoreverses: true)) {
                textScale = 1.05
            }
        }
    }
}

// MARK: - Monitoring HUD — Draggable FaceTime-style PIP

@available(iOS 26.0, *)
struct DrowsinessMonitorHUD: View {
    @ObservedObject var detector: DrowsinessDetector

    // Drag state
    @State private var position: CGPoint = CGPoint(x: UIScreen.main.bounds.width - 60, y: 120)
    @GestureState private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    // UI state
    @State private var isCollapsed = false
    @State private var expanded   = false

    private let pipW: CGFloat = 72
    private let pipH: CGFloat = 96
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
                    // ── Expanded: PIP + pill ──────────────────────────────────
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottomTrailing) {
                            if let layer = detector.cameraPreviewLayer {
                                CameraPreviewPIP(previewLayer: layer)
                                    .frame(width: expanded ? 120 : pipW,
                                           height: expanded ? 160 : pipH)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(borderColor, lineWidth: detector.state == .alarm ? 3 : 1.5)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
                            } else {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: pipW, height: pipH)
                            }

                            // Eye status badge
                            Image(systemName: eyeOverlayIcon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(borderColor, in: Circle())
                                .offset(x: 4, y: 4)
                        }
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35)) { expanded.toggle() }
                        }

                        // Status pill
                        DrowsinessStatusPill(state: detector.state)
                    }
                    // Drag to move
                    .position(clamp(position, in: geo.size,
                                    itemSize: CGSize(width: expanded ? 120 : pipW,
                                                     height: expanded ? 190 : pipH + 30)))
                    .offset(dragOffset)
                    .scaleEffect(isDragging ? 1.05 : 1.0)
                    .shadow(color: isDragging ? borderColor.opacity(0.5) : .clear, radius: 12)
                    .gesture(
                        dragGesture(in: geo.size,
                                    itemSize: CGSize(width: expanded ? 120 : pipW,
                                                     height: expanded ? 190 : pipH + 30))
                    )
                    .simultaneousGesture(
                        // Long-press to collapse to badge
                        LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.35)) { isCollapsed = true }
                        }
                    )
                    .animation(.spring(response: 0.35), value: expanded)
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
                .fill(borderColor)
                .frame(width: collapsedSize, height: collapsedSize)
                .shadow(color: borderColor.opacity(0.5), radius: 6)
            Image(systemName: eyeOverlayIcon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
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

    private var borderColor: Color {
        switch detector.state {
        case .monitoring:   return Color(red: 0.2, green: 0.78, blue: 0.35)
        case .eyesClosed:   return Color(red: 0.95, green: 0.50, blue: 0.15)
        case .alarm:        return .red
        default:            return Color(UIColor.systemGray3)
        }
    }

    private var eyeOverlayIcon: String {
        switch detector.state {
        case .monitoring:   return "eye.fill"
        case .eyesClosed:   return "exclamationmark.triangle.fill"
        case .alarm:        return "exclamationmark.octagon.fill"
        case .noFace:       return "person.fill.questionmark"
        case .inactive:     return "eye.slash"
        }
    }
}



