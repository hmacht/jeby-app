//
//  AppEnvironment.swift
//  Jeby
//
//  Reads runtime configuration (API base URL + key) from Environment.plist so
//  secrets and endpoints stay out of source and can be swapped per build.
//

import Foundation

/// Typed access to the values in `Environment.plist`.
struct AppEnvironment {

    /// Base URL of the jeby-go backend, without a trailing slash.
    let apiBaseURL: URL

    /// Key sent as the `X-API-Key` header on every request.
    let apiKey: String

    /// The shared environment, loaded once from the bundled `Environment.plist`.
    static let current: AppEnvironment = {
        do {
            return try AppEnvironment(bundle: .main)
        } catch {
            fatalError("Failed to load Environment.plist: \(error)")
        }
    }()

    enum ConfigError: Error, CustomStringConvertible {
        case missingFile
        case missingKey(String)
        case invalidURL(String)

        var description: String {
            switch self {
            case .missingFile:
                return "Environment.plist not found in the app bundle."
            case .missingKey(let key):
                return "Environment.plist is missing the '\(key)' key."
            case .invalidURL(let value):
                return "JEBY_API_URL is not a valid URL: \(value)"
            }
        }
    }

    init(bundle: Bundle) throws {
        guard
            let url = bundle.url(forResource: "Environment", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dict = plist as? [String: Any]
        else {
            throw ConfigError.missingFile
        }

        guard let rawURL = (dict["JEBY_API_URL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawURL.isEmpty else {
            throw ConfigError.missingKey("JEBY_API_URL")
        }
        guard let baseURL = URL(string: rawURL) else {
            throw ConfigError.invalidURL(rawURL)
        }
        guard let key = dict["JEBY_API_KEY"] as? String, !key.isEmpty else {
            throw ConfigError.missingKey("JEBY_API_KEY")
        }

        self.apiBaseURL = baseURL
        self.apiKey = key
    }
}
