import Foundation

struct DBPredictiveAlert: Codable {
    let id: UUID
    var vehicleId: UUID
    var riskLevel: String
    var riskScore: Double
    var triggeredReasons: [String]?
    var suggestedAction: String?
    var llmExplanation: String?
    var createdAt: Date
    var resolvedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId       = "vehicle_id"
        case riskLevel       = "risk_level"
        case riskScore       = "risk_score"
        case triggeredReasons = "triggered_reasons"
        case suggestedAction = "suggested_action"
        case llmExplanation  = "llm_explanation"
        case createdAt       = "created_at"
        case resolvedAt      = "resolved_at"
    }
}

let json = """
{
  "alerts": [
    {
      "id": "6c64f993-771a-45a6-8de2-b54eff5e083d",
      "vehicle_id": "f64e2c0a-6c1c-44e2-b87c-504ad4dcb284",
      "risk_level": "critical",
      "risk_score": 80,
      "triggered_reasons": [
        "The vehicle's next service date has already passed, indicating it is overdue for maintenance."
      ],
      "suggested_action": "Immediately pull the vehicle from service and schedule an emergency maintenance appointment.",
      "llm_explanation": "The vehicle's next service date has already passed, indicating it is overdue for maintenance.",
      "created_at": "2026-06-01T17:17:18.150407+00:00",
      "resolved_at": null
    }
  ]
}
""".data(using: .utf8)!

let fmsDecoder = JSONDecoder()
fmsDecoder.keyDecodingStrategy = .convertFromSnakeCase
fmsDecoder.dateDecodingStrategy = .custom { decoder in
    let container = try decoder.singleValueContainer()
    let dateStr = try container.decode(String.self)
    
    let isoFormatter = ISO8601DateFormatter()
    
    isoFormatter.formatOptions = [.withInternetDateTime]
    if let date = isoFormatter.date(from: dateStr) {
        return date
    }
    
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = isoFormatter.date(from: dateStr) {
        return date
    }
    
    let fallbackFormats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss.SZZZZZ",
        "yyyy-MM-dd HH:mm:ss.SSSSSS",
        "yyyy-MM-dd HH:mm:ss.SSS",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd"
    ]
    
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    for format in fallbackFormats {
        dateFormatter.dateFormat = format
        if let date = dateFormatter.date(from: dateStr) {
            return date
        }
    }
    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateStr)")
}

let fmsDirectDecoder = JSONDecoder()
// No keyDecodingStrategy = .convertFromSnakeCase so it honors custom CodingKeys!
fmsDirectDecoder.dateDecodingStrategy = fmsDecoder.dateDecodingStrategy

do {
    let result = try fmsDirectDecoder.decode([String: [DBPredictiveAlert]].self, from: json)
    print("Decoded successfully with direct decoder! Alerts count: \(result["alerts"]?.count ?? 0)")
} catch {
    print("Direct decoding failed: \(error)")
}
