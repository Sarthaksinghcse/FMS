//
//  AlertsFeedViewModel.swift
//  FMS
//
//  Created on 21/05/26.
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Alerts Feed View Model
@MainActor
final class AlertsFeedViewModel: ObservableObject {
    @Published var errorMessage: String? = nil
    
    /// Resolves an SOS Alert by setting status to .resolved
    /// BACKEND DEVS: Add your Supabase/cloud database call here.
    func resolveSOSAlert(alertId: UUID, context: ModelContext, alerts: [SOSAlert]) -> Bool {
        errorMessage = nil
        guard let alert = alerts.first(where: { $0.id == alertId }) else {
            errorMessage = "Alert not found."
            return false
        }
        
        alert.status = .resolved
        
        do {
            try context.save()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Sync resolution notification to Supabase
            let notification = DBNotification(
                id: UUID(),
                userId: alert.driverId,
                title: "SOS Alert Resolved",
                message: "Your emergency alert has been acknowledged and resolved by the fleet manager.",
                type: .emergency,
                isRead: false,
                createdAt: Date()
            )
            Task {
                try? await SupabaseManager.shared.createNotification(notification)
            }
            
            return true
        } catch {
            errorMessage = "Failed to resolve SOS: \(error.localizedDescription)"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return false
        }
    }
    
    /// Updates a Defect Report status
    /// BACKEND DEVS: Add your Supabase/cloud database call here.
    func updateDefectStatus(defectId: UUID, newStatus: DefectStatus, context: ModelContext, defects: [DefectReport]) -> Bool {
        errorMessage = nil
        guard let defect = defects.first(where: { $0.id == defectId }) else {
            errorMessage = "Defect report not found."
            return false
        }
        
        defect.status = newStatus
        
        do {
            try context.save()
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            return true
        } catch {
            errorMessage = "Failed to update defect: \(error.localizedDescription)"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return false
        }
    }
}

