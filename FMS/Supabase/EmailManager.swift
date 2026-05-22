//
//  EmailManager.swift
//  FMS
//  Created by Naman Yadav on 22/05/26.
//

import Foundation

/// A manager to handle sending email notifications through the Resend REST API.
public final class EmailManager {
    public static let shared = EmailManager()
    
    // Developer should replace this placeholder with a valid Resend API Key:
    // e.g. "re_1234567890..."
    private let apiKey = "re_U65DyUEE_LPnKJyDrj1m6qEHTY2MxePt8"
    
    // Sender configuration. Resend requires a verified domain unless sending from onboarding@resend.dev.
    private let senderEmail = "FMS System <onboarding@resend.dev>"
    
    private init() {}
    
    /// Struct representing the Resend API payload.
    private struct ResendPayload: Codable {
        let from: String
        let to: [String]
        let subject: String
        let html: String
    }
    
    /// Sends an email through the Resend API.
    private func sendEmail(to recipient: String, subject: String, htmlContent: String) async throws {
        // If API key is not configured, print info and throw error so caller knows but can log/ignore.
        guard apiKey != "re_YOUR_KEY" else {
            print(" EmailManager: Resend API Key is not set. Skipping email send to \(recipient).")
            throw NSError(domain: "EmailManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Resend API Key is not set."])
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
    
    /// Sends a welcome email containing plain-text credentials to a newly created driver account.
    public func sendWelcomeEmail(to email: String, name: String, passwordString: String) async throws {
        let subject = "Welcome to Fleeto!"
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
            <div class="header">Welcome to Fleeto! </div>
            <div class="content">
              <p>Hello <strong>\(name)</strong>,</p>
              <p>Your driver account has been successfully created by the Fleet Manager. You can now log in to the Fleeto app using the following credentials:</p>
              <div class="credentials">
                <strong>Email ID:</strong> \(email)<br>
                <strong>Password:</strong> \(passwordString)
              </div>
              <p>Please secure your password and log in to update your profile.</p>
            </div>
            <div class="footer">
              This is an automated notification from Fleeto. Please do not reply to this email.
            </div>
          </div>
        </body>
        </html>
        """
        
        try await sendEmail(to: email, subject: subject, htmlContent: html)
    }
    
    /// Sends a notification email to a driver when they are assigned a vehicle.
    public func sendVehicleAssignmentEmail(to email: String, name: String, vehicleReg: String, vehicleModel: String) async throws {
        let subject = "New Vehicle Assigned - Fleeto! "
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
              <p>Please perform the pre-trip inspection check in the Fleeto! application before beginning your shift.</p>
            </div>
            <div class="footer">
              This is an automated notification from Fleeto. Please do not reply to this email.
            </div>
          </div>
        </body>
        </html>
        """
        
        try await sendEmail(to: email, subject: subject, htmlContent: html)
    }
}
