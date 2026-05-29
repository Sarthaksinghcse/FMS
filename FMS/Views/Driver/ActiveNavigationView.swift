
//  ActiveNavigationView.swift
//  FMS — Apple Maps-style real-time navigation overlay
//
//  This view is embedded inside TripNavigationView's ZStack once isNavigating == true.
//  It is NOT a separate screen — it layers over the live MapKit map.

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Active Navigation Overlay

@available(iOS 26.0, *)
struct ActiveNavigationOverlay: View {
    @ObservedObject var nav: NavigationManager
    let onEndTrip: () -> Void
    let onSOS: () -> Void

    // Collapsed / expanded turn list
    @State private var showStepList = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // ── 1. Next-maneuver banner (top of screen, over map) ──────────
            nextManeuverBanner
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Spacer()

            // ── 2. Bottom drawer ───────────────────────────────────────────
            bottomDrawer
        }
    }

    // MARK: - Next Maneuver Banner (Apple Maps HUD)

    private var nextManeuverBanner: some View {
        let step = currentStep
        return HStack(spacing: 14) {
            // Direction arrow
            ZStack {
                Circle()
                    .fill(Color.fmsIndigo)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.fmsIndigo.opacity(0.45), radius: 8, y: 3)
                Image(systemName: step?.sfSymbol ?? "arrow.up")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                // Distance to maneuver
                Text(formattedDistance(nav.distanceToNextManeuver))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                // Street name / instruction
                Text(step?.instruction ?? "Head towards destination")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // ETA pill
            VStack(spacing: 2) {
                Text(formattedETA)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fmsIndigo)
                    .monospacedDigit()
                Text("ETA")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.fmsIndigo.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        )
    }

    // MARK: - Bottom Drawer

    private var bottomDrawer: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color(UIColor.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 10).padding(.bottom, 12)

            // Progress summary row
            HStack(spacing: 0) {
                NavMetricCell(
                    icon: "arrow.left.arrow.right",
                    value: formattedDistance(nav.remainingDistance),
                    label: "Remaining"
                )
                Divider().frame(height: 32)
                NavMetricCell(
                    icon: "clock",
                    value: formattedTime(nav.remainingTime),
                    label: "Time Left"
                )
                Divider().frame(height: 32)
                NavMetricCell(
                    icon: "location.north.fill",
                    value: currentSpeedText,
                    label: "Speed"
                )
            }
            .padding(.horizontal, 8)

            Divider().padding(.horizontal, 20).padding(.top, 8)

            // Expandable turn list
            if !nav.steps.isEmpty {
                turnListToggle
            }

            Divider().padding(.horizontal, 20).padding(.vertical, 4)

            // Action buttons row
            actionButtonsRow
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 22, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 22
            )
            .fill(.regularMaterial)
        )
        .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: -4)
    }

    // MARK: Turn List Toggle

    private var turnListToggle: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35)) { showStepList.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.fmsIndigo)
                    Text("Turn-by-Turn · \(nav.steps.count) steps")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.fmsIndigo)
                    Spacer()
                    // Highlight current step
                    Text("Step \(nav.currentStepIndex + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.fmsIndigo)
                        .clipShape(Capsule())
                    Image(systemName: showStepList ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if showStepList {
                Divider().padding(.leading, 16)
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(nav.steps) { step in
                                TurnStepBubble(
                                    step:      step,
                                    isCurrent: step.id == nav.currentStepIndex,
                                    isPast:    step.id < nav.currentStepIndex
                                )
                                .id(step.id)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                    .onChange(of: nav.currentStepIndex) { _, idx in
                        withAnimation { proxy.scrollTo(idx, anchor: .top) }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    // MARK: Action Buttons

    private var actionButtonsRow: some View {
        HStack(spacing: 10) {
            MapActionButton(label: "Defect", icon: "wrench.and.screwdriver.fill", style: .warning) {}
            MapActionButton(label: "SOS",    icon: "sos",                          style: .destructive) {
                onSOS()
            }
            MapActionButton(label: "End Trip", icon: "stop.fill",                 style: .destructive) {
                onEndTrip()
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Helpers

    private var currentStep: NavStep? {
        guard nav.steps.indices.contains(nav.currentStepIndex) else { return nil }
        return nav.steps[nav.currentStepIndex]
    }

    private var formattedETA: String {
        let arrival = Date().addingTimeInterval(nav.remainingTime)
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: arrival)
    }

    private var currentSpeedText: String {
        guard let speed = nav.userLocation?.speed, speed > 0 else { return "0.0 km/h" }
        return String(format: "%.1f km/h", speed * 3.6)
    }

    private func formattedDistance(_ metres: CLLocationDistance) -> String {
        if metres < 1000 {
            return String(format: "%.0f m", metres)
        }
        return String(format: "%.1f km", metres / 1000)
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600; let m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
    }
}

// MARK: - Turn Step Bubble

@available(iOS 26.0, *)
private struct TurnStepBubble: View {
    let step: NavStep
    let isCurrent: Bool
    let isPast: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Step icon circle
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 32, height: 32)
                Image(systemName: step.sfSymbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(step.instruction)
                    .font(.system(size: 13, weight: isCurrent ? .bold : .regular))
                    .foregroundStyle(isPast ? .tertiary : .primary)
                    .lineLimit(2)
                if step.distance > 0 {
                    Text(step.distance < 1000
                         ? String(format: "%.0f m", step.distance)
                         : String(format: "%.1f km", step.distance / 1000))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()

            // Active pulse indicator
            if isCurrent {
                Circle()
                    .fill(Color.fmsIndigo)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isCurrent ? Color.fmsIndigo.opacity(0.07) : Color.clear)

        if step.id < (step.id + 1) {
            Divider().padding(.leading, 58)
        }
    }

    private var circleColor: Color {
        if isPast    { return Color(UIColor.systemGray3) }
        if isCurrent { return Color.fmsIndigo }
        return Color(UIColor.systemGray2)
    }
}

// MARK: - NavMetricCell

@available(iOS 26.0, *)
private struct NavMetricCell: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}
