
import SwiftUI
struct ProfileMenuButton: View {

    let initials: String
    var avatarColor: Color      = AppTheme.Brand.primaryDeep
    var size: CGFloat           = 38
    let action: () -> Void

    var body: some View {
        Button {
            action()
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
    }
}

#Preview {
    HStack {
        Spacer()
        ProfileMenuButton(initials: "FM", avatarColor: AppTheme.Brand.primaryDeep) {}
        Spacer()
    }
    .padding()
}
