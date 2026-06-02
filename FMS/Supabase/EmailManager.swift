





import Foundation


public final class EmailManager {
    public static let shared = EmailManager()
    
    
    
    private let apiKey = "re_bRqYRGAK_FBttSS7qNy8F4LboUz2HeavF"
    
    
    private let senderEmail = "FMS System <onboarding@resend.dev>"
    
    private init() {}
    
    
    private struct ResendPayload: Codable {
        let from: String
        let to: [String]
        let subject: String
        let html: String
    }
    
    
    private func sendEmail(to recipient: String, subject: String, htmlContent: String) async throws {
        
        guard apiKey.starts(with: "re_") && apiKey.count > 20 else {
            print(" EmailManager: Resend API Key is not set or invalid. Skipping email send to \(recipient).")
            throw NSError(domain: "EmailManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Resend API Key is not set or invalid."])
        }
        
        let url = URL(string: "https://api.resend.com/emails")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ResendPayload(
            from: senderEmail,
            to: [recipient],
            subject: subject,
            html: htmlContent
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if !(200...299).contains(httpResponse.statusCode) {
                let responseString = String(data: data, encoding: .utf8) ?? "No details"
                print(" EmailManager: Resend API failed with status \(httpResponse.statusCode). Response: \(responseString)")
                throw NSError(domain: "EmailManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Resend API returned status \(httpResponse.statusCode): \(responseString)"])
            } else {
                print(" EmailManager: Email successfully sent to \(recipient) with subject: \"\(subject)\".")
            }
        }
    }
    
    
    public func sendWelcomeEmail(to email: String, name: String, passwordString: String) async throws {
        let subject = "Welcome to Carwaan!"
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #f6f9fc; margin: 0; padding: 20px; }
            .card { background-color: #ffffff; border-radius: 16px; padding: 32px; max-width: 600px; margin: 0 auto; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05); border: 1px solid #e5e7eb; }
            .header { font-size: 24px; font-weight: bold; color: #1e3a8a; margin-bottom: 16px; }
            .content { font-size: 16px; color: #374151; line-height: 1.6; }
            .credentials { background-color: #f3f4f6; border-radius: 12px; padding: 16px; margin: 24px 0; font-family: monospace; font-size: 15px; border-left: 4px solid #1e3a8a; }
            .footer { font-size: 12px; color: #9ca3af; margin-top: 32px; text-align: center; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="header">Welcome to Carwaan! </div>
            <div class="content">
              <p>Hello <strong>\(name)</strong>,</p>
              <p>Your driver account has been successfully created by the Fleet Manager. You can now log in to the Carwaan app using the following credentials:</p>
              <div class="credentials">
                <strong>Email ID:</strong> \(email)<br>
                <strong>Password:</strong> \(passwordString)
              </div>
              <p>Please secure your password and log in to update your profile.</p>
            </div>
            <div class="footer">
              This is an automated notification from Carwaan. Please do not reply to this email.
            </div>
          </div>
        </body>
        </html>
        """
        
        try await sendEmail(to: email, subject: subject, htmlContent: html)
    }
    
    
    public func sendVehicleAssignmentEmail(to email: String, name: String, vehicleReg: String, vehicleModel: String) async throws {
        let subject = "New Vehicle Assigned - Carwaan! "
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #f6f9fc; margin: 0; padding: 20px; }
            .card { background-color: #ffffff; border-radius: 16px; padding: 32px; max-width: 600px; margin: 0 auto; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05); border: 1px solid #e5e7eb; }
            .header { font-size: 24px; font-weight: bold; color: #10b981; margin-bottom: 16px; }
            .content { font-size: 16px; color: #374151; line-height: 1.6; }
            .details { background-color: #f3f4f6; border-radius: 12px; padding: 16px; margin: 24px 0; border-left: 4px solid #10b981; font-size: 14px; }
            .footer { font-size: 12px; color: #9ca3af; margin-top: 32px; text-align: center; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="header">New Vehicle Assigned </div>
            <div class="content">
              <p>Hello <strong>\(name)</strong>,</p>
              <p>You have been assigned a vehicle for your fleet operations. Here are the details of the assigned vehicle:</p>
              <div class="details">
                <strong>Registration Number:</strong> \(vehicleReg)<br>
                <strong>Vehicle Model:</strong> \(vehicleModel)
              </div>
              <p>Please perform the pre-trip inspection check in the Carwaan! application before beginning your shift.</p>
            </div>
            <div class="footer">
              This is an automated notification from Carwaan. Please do not reply to this email.
            </div>
          </div>
        </body>
        </html>
        """
        
        try await sendEmail(to: email, subject: subject, htmlContent: html)
    }
    
    
    public func sendTripAssignmentEmail(to email: String, name: String, tripCode: String, source: String, destination: String, startTime: Date, distance: Double) async throws {
        let subject = "New Trip Assigned: \(tripCode) - Carwaan!"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #f6f9fc; margin: 0; padding: 20px; }
            .card { background-color: #ffffff; border-radius: 16px; padding: 32px; max-width: 600px; margin: 0 auto; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05); border: 1px solid #e5e7eb; }
            .header { font-size: 24px; font-weight: bold; color: #1e3a8a; margin-bottom: 16px; }
            .content { font-size: 16px; color: #374151; line-height: 1.6; }
            .details { background-color: #f3f4f6; border-radius: 12px; padding: 16px; margin: 24px 0; border-left: 4px solid #1e3a8a; font-size: 14px; }
            .footer { font-size: 12px; color: #9ca3af; margin-top: 32px; text-align: center; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="header">New Trip Assigned </div>
            <div class="content">
              <p>Hello <strong>\(name)</strong>,</p>
              <p>A new trip has been assigned to you. Here are the route and departure details:</p>
              <div class="details">
                <strong>Trip Code:</strong> \(tripCode)<br>
                <strong>Route:</strong> \(source) &rarr; \(destination)<br>
                <strong>Departure Time:</strong> \(formatter.string(from: startTime))<br>
                <strong>Distance:</strong> \(String(format: "%.1f km", distance))
              </div>
              <p>Please perform the pre-trip inspection and log in to the Carwaan app to navigate your trip.</p>
            </div>
            <div class="footer">
              This is an automated notification from Carwaan. Please do not reply to this email.
            </div>
          </div>
        </body>
        </html>
        """
        try await sendEmail(to: email, subject: subject, htmlContent: html)
    }
}
