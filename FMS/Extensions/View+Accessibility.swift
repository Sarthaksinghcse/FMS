import SwiftUI

@available(iOS 26.0, *)
extension View {
    /// Applies a high contrast border if the high contrast accessibility setting is enabled
    @ViewBuilder
    func applyHighContrastBorder(cornerRadius: CGFloat = AppTheme.Radius.card) -> some View {
        self.modifier(HighContrastModifier(cornerRadius: cornerRadius))
    }
    
}

@available(iOS 26.0, *)
struct HighContrastModifier: ViewModifier {
    @ObservedObject var manager = AccessibilityManager.shared
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if manager.isHighContrastEnabled {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.black, lineWidth: 2)
                )
        } else {
            content
        }
    }
}
