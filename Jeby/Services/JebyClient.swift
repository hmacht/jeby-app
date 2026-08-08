//
//  JebyClient.swift
//  Jeby
//
//  Client for the jeby-go backend API. Mirrors the endpoints the web frontend
//  uses (/marine/vessels, /marine/conditions, /marine/forecast, and so on).
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
        try await get("/marine/vessels")
    }

    func stations() async throws -> [Station] {
        try await get("/marine/stations")
    }

    func conditions(vessel code: String) async throws -> Conditions {
        try await get("/marine/conditions", query: [URLQueryItem(name: "vessel", value: code)])
    }

    func images() async throws -> Images {
        try await get("/marine/images")
    }

    func forecastSummary() async throws -> ForecastSummary {
        try await get("/marine/forecast")
    }

    func activeAlerts() async throws -> [Alert] {
        try await get("/marine/alerts")
    }

    // MARK: - Users

    /// The signed-in user's profile, boats, pet, and what onboarding still needs.
    func profile(userID: String) async throws -> Profile {
        try await send(.get, "/users/\(userID)/profile", body: Optional<Never>.none)
    }

    /// Patches the name and/or photo. Fields left nil are untouched server-side.
    @discardableResult
    func updateProfile(
        userID: String,
        displayName: String? = nil,
        photoURL: String? = nil,
        bio: String? = nil
    ) async throws -> ProfileUser {
        try await send(.patch, "/users/\(userID)", body: UpdateProfileBody(
            displayName: displayName, photoUrl: photoURL, bio: bio
        ))
    }

    /// Every report filed on one day, newest first. Defaults to today on the
    /// Vineyard when no date is given.
    /// Public: no account needed, so this uses the plain API-key request rather
    /// than the token-bearing one.
    func feed(date: String? = nil, cursor: String? = nil) async throws -> FeedResponse {
        var query: [URLQueryItem] = []
        if let date { query.append(URLQueryItem(name: "date", value: date)) }
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await get("/users/posts", query: query)
    }

    /// Someone's profile, from tapping an author in the feed. Also public.
    func publicProfile(userID: String) async throws -> PublicProfile {
        try await get("/users/profiles/\(userID)")
    }

    /// More of someone's reports, after the page their profile carried.
    func publicPosts(userID: String, cursor: String) async throws -> PostPage {
        try await get("/users/profiles/\(userID)/posts", query: [URLQueryItem(name: "cursor", value: cursor)])
    }

    /// The signed-in user's own reports, newest first.
    func posts(userID: String, cursor: String? = nil) async throws -> PostPage {
        try await send(
            .get,
            "/users/\(userID)/posts",
            query: cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? [],
            body: Optional<Never>.none
        )
    }

    /// Files a report. The day it's filed under and its timestamp are both the
    /// server's, so a phone with a wrong clock can't misfile it.
    @discardableResult
    func createPost(userID: String, imageURL: String, caption: String, bumpyScore: Int) async throws -> UserPost {
        try await send(.post, "/users/\(userID)/posts", body: NewPost(
            imageUrl: imageURL, caption: caption, bumpyScore: bumpyScore
        ))
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

    func deletePost(userID: String, postID: String) async throws {
        try await sendNoContent(.delete, "/users/\(userID)/posts/\(postID)")
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
    private func send<Body: Encodable, T: Decodable>(
        _ method: Method,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Body?
    ) async throws -> T {
        try await perform(authorizedRequest(method, path, query: query, body: body))
    }

    /// For endpoints that answer 204 with no body — the deletes.
    private func sendNoContent(_ method: Method, _ path: String) async throws {
        let request = try await authorizedRequest(method, path, query: [], body: Optional<Never>.none)

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

    private func authorizedRequest<Body: Encodable>(
        _ method: Method,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Body?
    ) async throws -> URLRequest {
        guard let idToken else { throw JebyClientError.notAuthenticated }

        let base = baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw JebyClientError.invalidResponse
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw JebyClientError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(try await idToken())", forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        APILog.request(request)
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

        APILog.request(request)
        return try await perform(request)
    }

    /// Sends a prepared request and decodes the response.
    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let started = ContinuousClock.now

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            APILog.failure(request, reason: error.localizedDescription, since: started)
            throw JebyClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            APILog.failure(request, reason: "not an HTTP response", since: started)
            throw JebyClientError.invalidResponse
        }

        APILog.response(request, status: http.statusCode, bytes: data.count, since: started)

        guard (200..<300).contains(http.statusCode) else {
            // The body usually carries the backend's own {"error": "..."}, which
            // says far more than the status alone.
            APILog.body(data)
            throw JebyClientError.http(status: http.statusCode)
        }

        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            APILog.failure(request, reason: "could not decode \(T.self): \(error)", since: started)
            throw JebyClientError.decoding(error)
        }
    }

    /// Go emits RFC 3339 timestamps *with* fractional seconds, which
    /// `.iso8601` rejects outright — so both shapes are tried.
    private static let decoder: JSONDecoder = {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = withFraction.date(from: text) { return date }
            if let date = plain.date(from: text) { return date }
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Not an RFC 3339 timestamp: \(text)"
                )
            )
        }
        return decoder
    }()
}

// MARK: - Request bodies

/// A boat being saved. Specs are optional numbers in fixed units — feet,
/// pounds, horsepower.
struct NewVessel: Encodable {
    let name: String
    let description: String
    let imageUrl: String
    let homeHarbor: String
    let lengthFt: Double?
    let weightLb: Double?
    let horsepower: Double?
    let maxPassengers: Int?
}

private struct NewPet: Encodable {
    let name: String
    let imageUrl: String?
}

/// A report being filed. No day and no timestamp — both are the server's.
private struct NewPost: Encodable {
    let imageUrl: String
    let caption: String
    let bumpyScore: Int
}

/// One field of a PATCH body: left out, or set to a value that may be null.
///
/// A plain `Double?` can't express both — omitting the key and clearing the
/// value would encode identically, and the backend treats them as opposites.
/// Text fields don't need this because `""` is a distinct third value.
enum PatchValue<T: Encodable> {
    /// Not sent at all; the server keeps what it has.
    case unchanged
    /// Sent. A nil payload writes JSON null, which clears the field.
    case set(T?)

    func encode<Key: CodingKey>(into container: inout KeyedEncodingContainer<Key>, forKey key: Key) throws {
        switch self {
        case .unchanged:
            break
        case .set(.none):
            try container.encodeNil(forKey: key)
        case .set(.some(let value)):
            try container.encode(value, forKey: key)
        }
    }
}

/// A partial vessel update. Text fields follow JSONEncoder's default of omitting
/// nils; the numeric specs use PatchValue so clearing one is expressible.
struct VesselPatch: Encodable {
    var name: String?
    var description: String?
    var imageUrl: String?
    var homeHarbor: String?
    var lengthFt: PatchValue<Double> = .unchanged
    var weightLb: PatchValue<Double> = .unchanged
    var horsepower: PatchValue<Double> = .unchanged
    var maxPassengers: PatchValue<Int> = .unchanged

    enum CodingKeys: String, CodingKey {
        case name, description, imageUrl, homeHarbor, lengthFt, weightLb, horsepower, maxPassengers
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(homeHarbor, forKey: .homeHarbor)
        try lengthFt.encode(into: &container, forKey: .lengthFt)
        try weightLb.encode(into: &container, forKey: .weightLb)
        try horsepower.encode(into: &container, forKey: .horsepower)
        try maxPassengers.encode(into: &container, forKey: .maxPassengers)
    }
}

/// A partial pet update. Same nil-versus-empty rule as VesselPatch.
struct PetPatch: Encodable {
    var name: String?
    var imageUrl: String?
}

private struct UpdateProfileBody: Encodable {
    let displayName: String?
    let photoUrl: String?
    let bio: String?
}
