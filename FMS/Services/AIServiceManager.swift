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
        let data: Data = try await SupabaseManager.shared.client.functions.invoke(functionName)
        return try JSONDecoder.fmsDecoder.decode(T.self, from: data)
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
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
