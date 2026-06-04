import SwiftUI

// MARK: - Button Style

struct PremiumRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.04) : Color.clear)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Stat Card

struct ProfileStatCard: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let value: String
    let subtitle: String

    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconBg)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            Text(title)
                .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)

            Text(value)
                .font(.system(size: 24 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                .foregroundColor(AppTheme.Text.primary)

            Text(subtitle)
                .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                .foregroundColor(AppTheme.Text.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.medium)
        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
    }
}

// MARK: - Settings Row

struct ProfileSettingsRow: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconBg)
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                        .foregroundColor(AppTheme.Text.primary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                    .foregroundColor(AppTheme.Text.tertiary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PremiumRowButtonStyle())
    }
}

// MARK: - Inner Screen Header

struct ProfileInnerScreenHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 26 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(.system(size: 20 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                .foregroundColor(AppTheme.Text.primary)
            Text(subtitle)
                .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                .foregroundColor(AppTheme.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Toggle Row

struct ProfileToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var tintColor: Color = AppTheme.Brand.primary

    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                    .foregroundColor(AppTheme.Text.primary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                        .foregroundColor(AppTheme.Text.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(tintColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Info Row

struct ProfileInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = AppTheme.Text.primary

    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Form Field

struct ProfileFormField: View {
    let icon: String
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var iconColor: Color = AppTheme.Brand.primary

    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                .foregroundColor(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                    .foregroundColor(AppTheme.Text.tertiary)
                TextField(placeholder, text: $text)
                    .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                    .foregroundColor(AppTheme.Text.primary)
                    .keyboardType(keyboardType)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Secure Form Field

struct ProfileSecureFormField: View {
    let icon: String
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var iconColor: Color = AppTheme.Brand.primary

    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                .foregroundColor(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                    .foregroundColor(AppTheme.Text.tertiary)
                SecureField(placeholder, text: $text)
                    .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                    .foregroundColor(AppTheme.Text.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

