








import SwiftUI



enum AppTheme {

    
    enum Brand {
        
        static let primary      = Color(red: 0.20, green: 0.50, blue: 1.00)
        
        static let primaryDeep  = Color(red: 0.28, green: 0.35, blue: 0.92)
        
        static let royalBlue    = Color(red: 0.15, green: 0.38, blue: 0.90)
        
        static let accent       = Color(red: 0.93, green: 0.46, blue: 0.00)
        
        static let violet       = Color(red: 0.55, green: 0.35, blue: 0.95)
        
        static let teal         = Color(red: 0.05, green: 0.75, blue: 0.65)
        
        static let amber        = Color(red: 1.00, green: 0.60, blue: 0.10)
    }

    
    enum Status {
        
        static let success      = Color(red: 0.15, green: 0.75, blue: 0.45)
        
        static let danger       = Color(red: 0.95, green: 0.30, blue: 0.30)
        
        static let warning      = Color.orange
        
        static let purple       = Color.purple
        /// Neutral gray — pending, secondary, or inactive status
        static let neutral      = Color.gray
        /// Progress / in-progress status color
        static let progress     = Color(red: 0.93, green: 0.46, blue: 0.00)
    }

    
    enum Background {
        
        static let page         = Color(red: 0.97, green: 0.98, blue: 1.00)
        
        static let card         = Color.white
        
        static let auth         = Color.white
        
        static let driverStart  = Color(red: 0.08, green: 0.12, blue: 0.22)
        
        static let driverEnd    = Color(red: 0.12, green: 0.20, blue: 0.36)
    }

    
    enum Text {
        static let primary      = Color.black
        static let secondary    = Color.secondary
        static let tertiary     = Color.gray
        static let onDark       = Color.white
        static let onDarkMuted  = Color.white.opacity(0.6)
    }

    
    enum Glass {
        
        static let border       = Color.black.opacity(0.20)
        
        static let ringTrack    = Color(red: 0.90, green: 0.93, blue: 0.98)
    }

    
    enum Shadow {
        
        static let card         = Color.black.opacity(0.03)
        
        static let modal        = Color.black.opacity(0.20)
        
        static func primaryGlow(opacity: Double = 0.30) -> Color {
            Brand.royalBlue.opacity(opacity)
        }
    }

    
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
        static let gray         = Color.gray.opacity(0.12)
    }

    
    enum Radius {
        static let small: CGFloat   = 10
        static let medium: CGFloat  = 14
        static let large: CGFloat   = 18
        static let card: CGFloat    = 18
        static let modal: CGFloat   = 28
        static let form: CGFloat    = 32
    }

    
    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
    }
}
