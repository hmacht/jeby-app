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
    case notAuthenticated

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
        case .notAuthenticated:
            return "You need to be signed in to do that."
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
    /// Supplies a fresh Firebase ID token for the `/users` endpoints. Nil on a
    /// client built for the public conditions endpoints only.
    private let idToken: (@Sendable () async throws -> String)?

    init(
        environment: AppEnvironment = .current,
        session: URLSession = .shared,
        idToken: (@Sendable () async throws -> String)? = nil
    ) {
        self.baseURL = environment.apiBaseURL.appendingPathComponent("api/v1")
        self.apiKey = environment.apiKey
        self.session = session
        self.idToken = idToken
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

    // MARK: - Users

    /// The signed-in user's profile, boats, pet, and what onboarding still needs.
    func profile(userID: String) async throws -> Profile {
        try await send(.get, "/users/\(userID)/profile", body: Optional<Never>.none)
    }

    /// Patches the name and/or photo. Fields left nil are untouched server-side.
    @discardableResult
    func updateProfile(userID: String, displayName: String? = nil, photoURL: String? = nil) async throws -> ProfileUser {
        try await send(.patch, "/users/\(userID)", body: UpdateProfileBody(displayName: displayName, photoUrl: photoURL))
    }

    @discardableResult
    func createVessel(userID: String, _ vessel: NewVessel) async throws -> UserVessel {
        try await send(.post, "/users/\(userID)/vessels", body: vessel)
    }

    @discardableResult
    func updateVessel(userID: String, vesselID: String, _ patch: VesselPatch) async throws -> UserVessel {
        try await send(.patch, "/users/\(userID)/vessels/\(vesselID)", body: patch)
    }

    func deleteVessel(userID: String, vesselID: String) async throws {
        try await sendNoContent(.delete, "/users/\(userID)/vessels/\(vesselID)")
    }

    @discardableResult
    func createPet(userID: String, name: String, imageURL: String?) async throws -> Pet {
        try await send(.post, "/users/\(userID)/pets", body: NewPet(name: name, imageUrl: imageURL))
    }

    @discardableResult
    func updatePet(userID: String, petID: String, _ patch: PetPatch) async throws -> Pet {
        try await send(.patch, "/users/\(userID)/pets/\(petID)", body: patch)
    }

    func deletePet(userID: String, petID: String) async throws {
        try await sendNoContent(.delete, "/users/\(userID)/pets/\(petID)")
    }

    // MARK: - Request plumbing

    private enum Method: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    /// An authenticated request. Every `/users` route needs both the API key
    /// (this is the Jeby app) and a Firebase ID token (this is who's asking).
    private func send<Body: Encodable, T: Decodable>(_ method: Method, _ path: String, body: Body?) async throws -> T {
        try await perform(authorizedRequest(method, path, body: body))
    }

    /// For endpoints that answer 204 with no body — the deletes.
    private func sendNoContent(_ method: Method, _ path: String) async throws {
        let request = try await authorizedRequest(method, path, body: Optional<Never>.none)

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw JebyClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw JebyClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw JebyClientError.http(status: http.statusCode)
        }
    }

    private func authorizedRequest<Body: Encodable>(_ method: Method, _ path: String, body: Body?) async throws -> URLRequest {
        guard let idToken else { throw JebyClientError.notAuthenticated }

        let url = baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(try await idToken())", forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }

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

        return try await perform(request)
    }

    /// Sends a prepared request and decodes the response.
    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
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

// MARK: - Request bodies

/// A boat being saved. `code` is the per-user handle the backend requires; the
/// onboarding form derives it from the name.
struct NewVessel: Encodable {
    let code: String
    let name: String
    let description: String
    let imageUrl: String
    let weight: String
    let length: String
    let horsepower: String
    let maxPassengers: String
}

private struct NewPet: Encodable {
    let name: String
    let imageUrl: String?
}

/// A partial vessel update. JSONEncoder omits nil optionals, which is exactly
/// PATCH semantics: nil leaves the field alone, `""` clears it.
struct VesselPatch: Encodable {
    var code: String?
    var name: String?
    var description: String?
    var imageUrl: String?
    var weight: String?
    var length: String?
    var horsepower: String?
    var maxPassengers: String?
}

/// A partial pet update. Same nil-versus-empty rule as VesselPatch.
struct PetPatch: Encodable {
    var name: String?
    var imageUrl: String?
}

private struct UpdateProfileBody: Encodable {
    let displayName: String?
    let photoUrl: String?
}
