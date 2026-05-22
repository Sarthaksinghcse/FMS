//
//  AppTheme.swift
//  FMS
//
//  Central design token file — MVVM Architecture
//  All colors, typography sizes, spacing, and shadow styles are defined here.
//  Import this file (it's auto-included in the module) and reference via `AppTheme`.
//

import SwiftUI

// MARK: - App Theme (Single Source of Truth)

enum AppTheme {

    // MARK: - Brand Colors
    enum Brand {
        /// Primary royal blue — buttons, active icons, links, accents
        static let primary      = Color(red: 0.20, green: 0.50, blue: 1.00)
        /// Deeper indigo variant — profile avatar, filled highlights
        static let primaryDeep  = Color(red: 0.28, green: 0.35, blue: 0.92)
        /// Auth-screen royal blue (slightly different hue for the login card)
        static let royalBlue    = Color(red: 0.15, green: 0.38, blue: 0.90)
        /// Accent orange — secondary CTAs, warnings
        static let accent       = Color(red: 0.93, green: 0.46, blue: 0.00)
        /// Violet / purple — driver stats, secondary icons
        static let violet       = Color(red: 0.55, green: 0.35, blue: 0.95)
        /// Teal — live trips, realtime indicators
        static let teal         = Color(red: 0.05, green: 0.75, blue: 0.65)
        /// Amber — shift / maintenance icons
        static let amber        = Color(red: 1.00, green: 0.60, blue: 0.10)
    }

    // MARK: - Semantic / Status Colors
    enum Status {
        /// Success green — completed, active, positive trends
        static let success      = Color(red: 0.15, green: 0.75, blue: 0.45)
        /// Danger red — errors, alerts, negative trends, badges
        static let danger       = Color(red: 0.95, green: 0.30, blue: 0.30)
        /// Warning orange — in-progress, medium priority
        static let warning      = Color.orange
        /// Purple — low-stock, special indicators
        static let purple       = Color.purple
    }

    // MARK: - Background Colors
    enum Background {
        /// App-wide page background (soft blue-white)
        static let page         = Color(red: 0.97, green: 0.98, blue: 1.00)
        /// Card / sheet surface
        static let card         = Color.white
        /// Auth screen background
        static let auth         = Color.white
        /// Driver dashboard dark gradient — start
        static let driverStart  = Color(red: 0.08, green: 0.12, blue: 0.22)
        /// Driver dashboard dark gradient — end
        static let driverEnd    = Color(red: 0.12, green: 0.20, blue: 0.36)
    }

    // MARK: - Text Colors
    enum Text {
        static let primary      = Color.black
        static let secondary    = Color.secondary
        static let tertiary     = Color.gray
        static let onDark       = Color.white
        static let onDarkMuted  = Color.white.opacity(0.6)
    }

    // MARK: - Glass / Border
    enum Glass {
        /// Subtle border for glass-effect containers
        static let border       = Color.black.opacity(0.20)
        /// Circular progress track ring
        static let ringTrack    = Color(red: 0.90, green: 0.93, blue: 0.98)
    }

    // MARK: - Shadows
    enum Shadow {
        /// Standard card shadow
        static let card         = Color.black.opacity(0.03)
        /// Stronger modal / overlay shadow
        static let modal        = Color.black.opacity(0.20)
        /// Primary button glow shadow
        static func primaryGlow(opacity: Double = 0.30) -> Color {
            Brand.royalBlue.opacity(opacity)
        }
    }

    // MARK: - Icon Background Tints (semantic pastel fills)
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

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
    }
}
