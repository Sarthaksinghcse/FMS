






import SwiftUI
import SwiftData
import Combine


@MainActor
final class EditVehicleViewModel: ObservableObject {
    private let vehicle: Vehicle
    
    @Published var registrationNumber: String = ""
    @Published var vinNumber: String = ""
    @Published var make: String = ""
    @Published var model: String = ""
    @Published var yearString: String = ""
    @Published var odometerString: String = ""
    
    @Published var vehicleType: VehicleType = .truck
    @Published var fuelType: FuelType = .diesel
    @Published var status: VehicleStatus = .active
    
    @Published var errorMessage: String? = nil
    @Published var isSaveSuccessful: Bool = false
    
    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        self.registrationNumber = vehicle.registrationNumber
        self.vinNumber = vehicle.vinNumber
        self.make = vehicle.make
        self.model = vehicle.model
        self.yearString = String(vehicle.year)
        self.odometerString = String(vehicle.odometerReading)
        self.vehicleType = vehicle.vehicleType
        self.fuelType = vehicle.fuelType
        self.status = vehicle.status
    }
    
    
    func validate() -> Bool {
        errorMessage = nil
        
        let cleanedReg = registrationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedVin = vinNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedMake = make.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedReg.isEmpty else {
            errorMessage = "Registration number is required."
            return false
        }
        
        guard !cleanedVin.isEmpty else {
            errorMessage = "VIN is required."
            return false
        }
        
        guard !cleanedMake.isEmpty else {
            errorMessage = "Manufacturer (Make) is required."
            return false
        }
        
        guard !cleanedModel.isEmpty else {
            errorMessage = "Vehicle model is required."
            return false
        }
        
        guard let year = Int(yearString), year >= 1900 && year <= Calendar.current.component(.year, from: Date()) + 1 else {
            errorMessage = "Please enter a valid manufacture year."
            return false
        }
        
        guard let odometer = Double(odometerString), odometer >= 0 else {
            errorMessage = "Odometer reading must be a positive number."
            return false
        }
        
        return true
    }
    
    
    
    func saveEdits(context: ModelContext) -> Bool {
        guard validate() else { return false }
        
        let cleanedReg = registrationNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanedVin = vinNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanedMake = make.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let year = Int(yearString) ?? vehicle.year
        let odometer = Double(odometerString) ?? vehicle.odometerReading
        
        
        vehicle.registrationNumber = cleanedReg
        vehicle.vinNumber = cleanedVin
        vehicle.make = cleanedMake
        vehicle.model = cleanedModel
        vehicle.year = year
        vehicle.vehicleType = vehicleType
        vehicle.fuelType = fuelType
        vehicle.odometerReading = odometer
        vehicle.status = status
        vehicle.updatedAt = Date()
        
        do {
            try context.save()
            
            let dbVehicle = vehicle.asDBVehicle
            Task {
                do {
                    try await SupabaseManager.shared.updateVehicle(dbVehicle)
                } catch {
                    print("Failed to sync vehicle edits to Supabase: \(error)")
                }
            }
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            isSaveSuccessful = true
            return true
        } catch {
            errorMessage = "Failed to update vehicle: \(error.localizedDescription)"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return false
        }
    }
    
    
    
    func deleteVehicle(context: ModelContext) -> Bool {
        context.delete(vehicle)
        do {
            try context.save()
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            return true
        } catch {
            errorMessage = "Failed to delete vehicle: \(error.localizedDescription)"
            return false
        }
    }
}
