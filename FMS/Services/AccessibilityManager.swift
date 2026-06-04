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
    
    // Driver settings
    @Published public var driverLargeTapTargets: Bool {
        didSet { UserDefaults.standard.set(driverLargeTapTargets, forKey: "accessibility_driver_largeTapTargets") }
    }
    @Published public var driverAudioPrompts: Bool {
        didSet { UserDefaults.standard.set(driverAudioPrompts, forKey: "accessibility_driver_audioPrompts") }
    }
    @Published public var driverScreenFlashAlerts: Bool {
        didSet { UserDefaults.standard.set(driverScreenFlashAlerts, forKey: "accessibility_driver_screenFlashAlerts") }
    }
    
    // Fleet settings
    @Published public var fleetColorFilterStatus: Bool {
        didSet { UserDefaults.standard.set(fleetColorFilterStatus, forKey: "accessibility_fleet_colorFilterStatus") }
    }
    @Published public var fleetSpeakLogs: Bool {
        didSet { UserDefaults.standard.set(fleetSpeakLogs, forKey: "accessibility_fleet_speakLogs") }
    }
    
    // Maintenance settings
    @Published public var maintenanceOutdoorContrast: Bool {
        didSet { UserDefaults.standard.set(maintenanceOutdoorContrast, forKey: "accessibility_maintenance_outdoorContrast") }
    }
    @Published public var maintenanceSpeakTasks: Bool {
        didSet { UserDefaults.standard.set(maintenanceSpeakTasks, forKey: "accessibility_maintenance_speakTasks") }
    }
    
    private init() {
        self.isLargeTextEnabled = UserDefaults.standard.bool(forKey: "accessibility_largeText")
        self.isHighContrastEnabled = UserDefaults.standard.bool(forKey: "accessibility_highContrast")
        
        let savedColorBlind = UserDefaults.standard.string(forKey: "accessibility_colorBlindMode") ?? ""
        self.colorBlindMode = ColorBlindType(rawValue: savedColorBlind) ?? .none
        
        self.driverLargeTapTargets = UserDefaults.standard.bool(forKey: "accessibility_driver_largeTapTargets")
        self.driverAudioPrompts = UserDefaults.standard.bool(forKey: "accessibility_driver_audioPrompts")
        self.driverScreenFlashAlerts = UserDefaults.standard.bool(forKey: "accessibility_driver_screenFlashAlerts")
        
        self.fleetColorFilterStatus = UserDefaults.standard.bool(forKey: "accessibility_fleet_colorFilterStatus")
        self.fleetSpeakLogs = UserDefaults.standard.bool(forKey: "accessibility_fleet_speakLogs")
        
        self.maintenanceOutdoorContrast = UserDefaults.standard.bool(forKey: "accessibility_maintenance_outdoorContrast")
        self.maintenanceSpeakTasks = UserDefaults.standard.bool(forKey: "accessibility_maintenance_speakTasks")
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
