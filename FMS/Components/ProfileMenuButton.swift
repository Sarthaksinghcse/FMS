//
//  ProfileMenuButton.swift
//  FMS
//
//  Reusable round profile-avatar button.
//  Tapping it pops up a small menu with "Sign Out".
//  Works on all three dashboards (Fleet, Maintenance, Driver).
//

import SwiftUI

// MARK: - Profile Menu Button

/// A tappable circular avatar that shows a Sign Out popover.
/// - Parameters:
///   - initials: 1-2 letters shown inside the circle (e.g. "FM", "M", "D")
///   - avatarColor: Fill color of the circle
///   - size: Diameter of the circle (default 38)
struct ProfileMenuButton: View {

    let initials: String
    var avatarColor: Color      = AppTheme.Brand.primaryDeep
    var size: CGFloat           = 38

    @State private var showMenu = false
    @StateObject private var auth = SupabaseManager.shared

    var body: some View {
        Button {
            showMenu = true
        } label: {
            ZStack {
                Circle()
                    .fill(avatarColor)
                    .frame(width: size, height: size)
                    .shadow(color: avatarColor.opacity(0.35), radius: 6, y: 2)

                Text(initials)
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showMenu, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
            ProfilePopoverContent(initials: initials, avatarColor: avatarColor)
                .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Popover Content

private struct ProfilePopoverContent: View {

    let initials: String
    let avatarColor: Color
    @StateObject private var auth = SupabaseManager.shared
    @State private var isSigningOut = false

    var body: some View {
        VStack(spacing: 0) {

            // ── Avatar header ───────────────────────────────────
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(avatarColor)
                        .frame(width: 56, height: 56)
                        .shadow(color: avatarColor.opacity(0.30), radius: 8, y: 3)

                    Text(initials)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                if let user = auth.currentUser {
                    Text(user.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(user.email)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()

            // ── Sign Out row ────────────────────────────────────
            Button {
                isSigningOut = true
                Task {
                    try? await auth.signOut()
                    isSigningOut = false
                }
            } label: {
                HStack(spacing: 10) {
                    if isSigningOut {
                        ProgressView()
                            .tint(Color(red: 0.85, green: 0.15, blue: 0.15))
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(red: 0.85, green: 0.15, blue: 0.15))
                            .frame(width: 18)
                    }

                    Text(isSigningOut ? "Signing out…" : "Sign Out")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(red: 0.85, green: 0.15, blue: 0.15))

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSigningOut)
        }
        .frame(width: 220)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    HStack {
        Spacer()
        ProfileMenuButton(initials: "FM", avatarColor: AppTheme.Brand.primaryDeep)
        Spacer()
    }
    .padding()
}
