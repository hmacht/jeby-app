//
//  JebyClient.swift
//  Jeby
//
//  Client for the jeby-go backend API. Mirrors the endpoints the web frontend
//  uses (/vessels, /stations, /conditions, /images, /forecast/marine, /alerts).
//  Each call sends the configured X-API-Key header and decodes the JSON payload.
//

import Foundation

enum JebyClientError: Error, LocalizedError {
    case invalidResponse
    case http(status: Int)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .http(let status):
            return "The server responded with status \(status)."
        case .decoding:
            return "Couldn't read the data from the server."
        case .transport:
            return "Couldn't reach the server. Check your connection."
        }
    }
}

/// Talks to the jeby-go backend. The backend is Vineyard-only, so buoy/zone are
/// fixed server-side and no location params are needed — the client only chooses
/// which vessel to score.
protocol JebyClientProtocol: Sendable {
    func vessels() async throws -> [Vessel]
    func stations() async throws -> [Station]
    func conditions(vessel code: String) async throws -> Conditions
    func images() async throws -> Images
    func forecastSummary() async throws -> ForecastSummary
    func activeAlerts() async throws -> [Alert]
}

struct JebyClient: JebyClientProtocol {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession

    init(
        environment: AppEnvironment = .current,
        session: URLSession = .shared
    ) {
        self.baseURL = environment.apiBaseURL.appendingPathComponent("api/v1")
        self.apiKey = environment.apiKey
        self.session = session
    }

    func vessels() async throws -> [Vessel] {
        try await get("/vessels")
    }

    func stations() async throws -> [Station] {
        try await get("/stations")
    }

    func conditions(vessel code: String) async throws -> Conditions {
        try await get("/conditions", query: [URLQueryItem(name: "vessel", value: code)])
    }

    func images() async throws -> Images {
        try await get("/images")
    }

    func forecastSummary() async throws -> ForecastSummary {
        try await get("/forecast/marine")
    }

    func activeAlerts() async throws -> [Alert] {
        try await get("/alerts")
    }

    // MARK: - Request plumbing

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        let base = baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw JebyClientError.invalidResponse
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else {
            throw JebyClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw JebyClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw JebyClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw JebyClientError.http(status: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw JebyClientError.decoding(error)
        }
    }
}
