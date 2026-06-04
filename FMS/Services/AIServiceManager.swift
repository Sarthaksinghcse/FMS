// FMS/Services/AIServiceManager.swift
import Foundation
import Supabase
import Observation

@Observable
final class AIServiceManager {
    static let shared = AIServiceManager()

    var lastRefreshTimes: [String: Date] = [:]

    /// Invoke a Supabase Edge Function and decode the result
    func invoke<T: Decodable>(_ functionName: String) async throws -> T {
        do {
            return try await SupabaseManager.shared.client.functions.invoke(functionName)
        } catch {
            print("⚠️ AIServiceManager: Supabase client functions.invoke failed natively for \(functionName): \(error)")
            throw error
        }
    }

    /// Returns true if the given key hasn't been refreshed in `hours` hours
    func shouldRefresh(_ key: String, hours: Double = 6) -> Bool {
        guard let last = lastRefreshTimes[key] else { return true }
        return Date().timeIntervalSince(last) > hours * 3600
    }

    func markRefreshed(_ key: String) {
        lastRefreshTimes[key] = Date()
    }
}

extension JSONDecoder {
    static let fmsDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom(fmsDateDecoderClosure)
        return d
    }()

    static let fmsDirectDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom(fmsDateDecoderClosure)
        return d
    }()
    
    private static let fmsDateDecoderClosure: @Sendable (any Decoder) throws -> Date = { decoder in
        let container = try decoder.singleValueContainer()
        let rawDateStr = try container.decode(String.self)
        
        // Normalize microseconds (more than 3 fractional digits) to milliseconds (3 digits)
        // so that ISO8601DateFormatter can natively parse it across all iOS versions.
        var dateStr = rawDateStr
        if let dotIndex = dateStr.firstIndex(of: ".") {
            var endIndex = dateStr.index(after: dotIndex)
            while endIndex < dateStr.endIndex, dateStr[endIndex].isNumber {
                endIndex = dateStr.index(after: endIndex)
            }
            let fractionCount = dateStr.distance(from: dotIndex, to: endIndex) - 1
            if fractionCount > 3 {
                let msEndIndex = dateStr.index(dotIndex, offsetBy: 4)
                dateStr.replaceSubrange(msEndIndex..<endIndex, with: "")
            }
        }
        
        // 1. Try ISO8601DateFormatter
        let isoFormatter = ISO8601DateFormatter()
        
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateStr) {
            return date
        }
        
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateStr) {
            return date
        }
        
        // 2. Try DateFormatter fallback for Postgres microsecond precision, etc.
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
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(rawDateStr)")
    }
}
