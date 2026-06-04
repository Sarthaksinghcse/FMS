//
//  Theme.swift
//  FMS
//

import SwiftUI

struct Theme {
    static var royalBlue: Color {
        switch AccessibilityManager.shared.colorBlindMode {
        case .tritanopia:
            // Tritanopia struggles with Blue. Shift to a distinct Cyan or Red.
            return Color(red: 0.0, green: 0.6, blue: 0.5) // Deep Teal/Cyan
        default:
            return Color(red: 0.15, green: 0.38, blue: 0.90)
        }
    }
    
    static var darkOrange: Color {
        switch AccessibilityManager.shared.colorBlindMode {
        case .protanopia, .deuteranopia:
            // Red-Green blindness struggles with Orange. Shift to bright Yellow.
            return Color(red: 1.0, green: 0.85, blue: 0.0)
        case .tritanopia:
            // Tritanopia struggles with Yellow/Orange. Shift to Pink/Red.
            return Color(red: 0.9, green: 0.2, blue: 0.4)
        case .none:
            return Color(red: 0.93, green: 0.46, blue: 0.0)
        }
    }
    
    static var fmsRed: Color {
        switch AccessibilityManager.shared.colorBlindMode {
        case .protanopia, .deuteranopia:
            // Shift red to Magenta or Blue for red-blindness
            return Color(red: 0.7, green: 0.0, blue: 0.7)
        default:
            return Color(red: 0.88, green: 0.12, blue: 0.12).opacity(0.6)
        }
    }
    
    static let clearWhite = Color.white
}
