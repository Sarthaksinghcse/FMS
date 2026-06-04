import SwiftUI
import Combine

public final class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()
    
    // Global Settings
    @Published public var isLargeTextEnabled: Bool {
        didSet { UserDefaults.standard.set(isLargeTextEnabled, forKey: "accessibility_largeText") }
    }
    @Published public var isHighContrastEnabled: Bool {
        didSet { UserDefaults.standard.set(isHighContrastEnabled, forKey: "accessibility_highContrast") }
    }
    @Published public var colorBlindMode: ColorBlindType {
        didSet { UserDefaults.standard.set(colorBlindMode.rawValue, forKey: "accessibility_colorBlindMode") }
    }
    
    private init() {
        self.isLargeTextEnabled = UserDefaults.standard.bool(forKey: "accessibility_largeText")
        self.isHighContrastEnabled = UserDefaults.standard.bool(forKey: "accessibility_highContrast")
        
        let savedColorBlind = UserDefaults.standard.string(forKey: "accessibility_colorBlindMode") ?? ""
        self.colorBlindMode = ColorBlindType(rawValue: savedColorBlind) ?? .none
    }
}

public enum ColorBlindType: String, CaseIterable, Identifiable {
    case none = "None"
    case deuteranopia = "Deuteranopia (Red-Green)"
    case protanopia = "Protanopia (Red-Green)"
    case tritanopia = "Tritanopia (Blue-Yellow)"
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .none: return "Off"
        case .deuteranopia: return "Deuteranopia"
        case .protanopia: return "Protanopia"
        case .tritanopia: return "Tritanopia"
        }
    }
}
