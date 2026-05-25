//
//  SOSCountdownOverlay.swift
//  FMS
//
//  Premium SOS countdown overlay with animated ring, pulsing effect,
//  and haptic feedback. Used from both Quick Actions and Map Navigation.
//  Target: iOS 26+
//

import SwiftUI

@available(iOS 26.0, *)
struct SOSCountdownOverlay: View {
    @Binding var isPresented: Bool
    var onTriggered: () -> Void

    private let totalSeconds = 5
    @State private var remaining = 5
    @State private var progress: CGFloat = 1.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var numberScale: CGFloat = 1.0
    @State private var timer: Timer?
    @State private var triggered = false

    var body: some View {
        ZStack {
            // Fullscreen dark red backdrop
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 0) {

                Spacer()

                // ── Pulsing outer ring ──────────────────────────────────
                ZStack {
                    // Outer pulse rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.red.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                            .frame(width: 200 + CGFloat(i) * 40, height: 200 + CGFloat(i) * 40)
                            .scaleEffect(pulseScale)
                    }

                    // Background track
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 10)
                        .frame(width: 180, height: 180)

                    // Animated countdown ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.red,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)

                    // Inner filled circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.red.opacity(0.6), Color.red.opacity(0.2)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)

                    // Countdown number
                    if !triggered {
                        Text("\(remaining)")
                            .font(.system(size: 72, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .scaleEffect(numberScale)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: remaining)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Spacer().frame(height: 40)

                // ── Labels ──────────────────────────────────────────────
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sos")
                            .font(.system(size: 16, weight: .bold))
                        Text("EMERGENCY SOS")
                            .font(.system(size: 18, weight: .heavy))
                            .tracking(1.5)
                    }
                    .foregroundStyle(.white)

                    if !triggered {
                        Text("Sending emergency alert in \(remaining) seconds…")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .contentTransition(.numericText())
                    } else {
                        Text("Emergency alert sent to fleet manager!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Text("Your GPS location will be shared.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                // ── Cancel / Done button ────────────────────────────────
                if !triggered {
                    Button {
                        cancelCountdown()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                            Text("Cancel")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                } else {
                    Button {
                        isPresented = false
                    } label: {
                        Text("Done")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.red.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear { startCountdown() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Timer

    private func startCountdown() {
        remaining = totalSeconds
        progress = 1.0
        triggered = false

        // Pulse animation
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.08
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if remaining > 1 {
                    remaining -= 1
                    progress = CGFloat(remaining - 1) / CGFloat(totalSeconds)

                    // Number pop
                    numberScale = 1.3
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                        numberScale = 1.0
                    }

                    // Haptic tick
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                } else {
                    // Countdown done — trigger SOS
                    timer?.invalidate()
                    timer = nil
                    progress = 0
                    triggered = true

                    // Strong haptic
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)

                    onTriggered()
                }
            }
        }
    }

    private func cancelCountdown() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
    }
}
