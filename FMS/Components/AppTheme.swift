//
//  AppTheme.swift
//  FMS
//

import SwiftUI

enum AppTheme {

    // MARK: - Brand Colors
    enum Brand {
        static let primary      = Theme.royalBlue
        static let primaryDeep  = Theme.royalBlue
        static let royalBlue    = Theme.royalBlue
        static let accent       = Theme.darkOrange.opacity(0.8)
        static let violet       = Theme.royalBlue.opacity(0.8)
        static let teal         = Theme.royalBlue.opacity(0.6)
        static let amber        = Theme.darkOrange
    }

    // MARK: - Status Colors (Blue, Red & Orange)
    enum Status {
        static var success: Color {
            return Theme.royalBlue
        }
        
        static var danger: Color {
            return Theme.fmsRed
        }
        
        static var warning: Color {
            return Theme.darkOrange
        }
        
        static var purple: Color {
            return Theme.royalBlue
        }
        
        static var neutral: Color {
            return Theme.royalBlue.opacity(0.4)
        }
        
        static var progress: Color {
            return Theme.darkOrange
        }
    }

    // MARK: - Background Colors
    enum Background {
        static var page: Color {
            AccessibilityManager.shared.isHighContrastEnabled ? .white : Color(red: 0.96, green: 0.97, blue: 0.99)
        }
        static let card         = Theme.clearWhite
        static let auth         = Theme.clearWhite
        static var driverStart: Color {
            AccessibilityManager.shared.isHighContrastEnabled ? .black : Color(red: 0.05, green: 0.13, blue: 0.30)
        }
        static var driverEnd: Color {
            AccessibilityManager.shared.isHighContrastEnabled ? .black : Color(red: 0.08, green: 0.20, blue: 0.48)
        }
    }

    // MARK: - Text Colors
    enum Text {
        static var primary: Color {
            AccessibilityManager.shared.isHighContrastEnabled ? .black : Color.black
        }
        static var secondary: Color {
            AccessibilityManager.shared.isHighContrastEnabled ? .black : Color.secondary
        }
        static var tertiary: Color {
            AccessibilityManager.shared.isHighContrastEnabled ? .black : Color.gray
        }
        static let onDark       = Theme.clearWhite
        static var onDarkMuted: Color {
            AccessibilityManager.shared.isHighContrastEnabled ? .white : Theme.clearWhite.opacity(0.6)
        }
    }

    // MARK: - Glassmorphism & UI Borders
    enum Glass {
        static var border: Color {
            AccessibilityManager.shared.isHighContrastEnabled ? .black : Color.black.opacity(0.12)
        }
        static var ringTrack: Color {
            AccessibilityManager.shared.isHighContrastEnabled ? .black.opacity(0.3) : Theme.royalBlue.opacity(0.10)
        }
    }

    // MARK: - Shadows
    enum Shadow {
        static var card: Color {
            AccessibilityManager.shared.isHighContrastEnabled ? .black.opacity(0.15) : Color.black.opacity(0.03)
        }
        static let modal        = Color.black.opacity(0.20)
        static func primaryGlow(opacity: Double = 0.30) -> Color {
            Theme.royalBlue.opacity(opacity)
        }
    }

    // MARK: - Icon Background Containers
    enum IconBg {
        static let blue         = Brand.primary.opacity(0.12)
        static let green        = Status.success.opacity(0.12)
        static let red          = Status.danger.opacity(0.12)
        static let orange       = Status.warning.opacity(0.12)
        static let purple       = Status.purple.opacity(0.12)
        static let indigo       = Brand.primaryDeep.opacity(0.12)
        static let violet       = Brand.violet.opacity(0.12)
        static let teal         = Brand.teal.opacity(0.12)
        static let amber        = Brand.amber.opacity(0.12)
        static let gray         = Theme.royalBlue.opacity(0.12)
    }

    // MARK: - Corner Radii
    enum Radius {
        static let small: CGFloat   = 10
        static let medium: CGFloat  = 14
        static let large: CGFloat   = 18
        static let card: CGFloat    = 18
        static let modal: CGFloat   = 28
        static let form: CGFloat    = 32
    }

    // MARK: - Spacings
    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
    }
}
