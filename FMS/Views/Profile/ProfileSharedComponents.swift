







import SwiftUI



struct ProfileStatCard: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconBg)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.Text.primary)

            Text(subtitle)
                .font(.system(size: 11))
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



struct ProfileSettingsRow: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Text.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Text.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Text.tertiary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}



struct ProfileInnerScreenHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.Text.primary)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}



struct ProfileToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Text.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Text.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppTheme.Brand.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}



struct ProfileInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = AppTheme.Text.primary

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
