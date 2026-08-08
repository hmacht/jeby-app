//
//  APILog.swift
//  Jeby
//
//  Readable console output for the backend calls, so a bad request is obvious
//  from the Xcode log without reaching for a proxy:
//
//      → GET    /users/posts?date=2025-07-04
//      ← 200    GET    /users/posts             142 ms   8.4 KB
//      ← 404    DELETE /users/…/posts/abc        38 ms    52 B
//        ↳ {"error": "report not found"}
//
//  Debug builds only. Everything here compiles to nothing in Release, so a
//  shipped build never writes request URLs — some carry a user id — to the
//  device log.
//

import Foundation

enum APILog {

    /// Logged as a request goes out, so a call that never returns is still
    /// visible in the log.
    static func request(_ request: URLRequest) {
        #if DEBUG
        print("→ \(method(request))  \(path(request))")
        #endif
    }

    /// Logged when a request comes back, whatever the status.
    static func response(_ request: URLRequest, status: Int, bytes: Int, since start: ContinuousClock.Instant) {
        #if DEBUG
        let mark = (200..<300).contains(status) ? "←" : "✗"
        print("\(mark) \(status)  \(method(request))  \(path(request))  \(duration(since: start))  \(size(bytes))")
        #endif
    }

    /// Logged when the request never produced a status — no network, a bad
    /// response, or a body we couldn't decode.
    static func failure(_ request: URLRequest, reason: String, since start: ContinuousClock.Instant) {
        #if DEBUG
        print("✗ ---  \(method(request))  \(path(request))  \(duration(since: start))")
        print("  ↳ \(reason)")
        #endif
    }

    /// The response body, printed after a failing status.
    static func body(_ data: Data) {
        #if DEBUG
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
        let collapsed = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
        print("  ↳ \(collapsed.prefix(300))")
        #endif
    }

    #if DEBUG
    private static func method(_ request: URLRequest) -> String {
        (request.httpMethod ?? "?").padding(toLength: 6, withPad: " ", startingAt: 0)
    }

    /// Path and query only — the host is the same every time and just adds noise.
    private static func path(_ request: URLRequest) -> String {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return request.url?.absoluteString ?? "?"
        }

        // Drop the /api/v1 prefix; every call has it.
        var text = components.path.replacingOccurrences(of: "/api/v1", with: "")
        if let query = components.query {
            text += "?\(query)"
        }
        return text
    }

    private static func duration(since start: ContinuousClock.Instant) -> String {
        let ms = (ContinuousClock.now - start).components.attoseconds / 1_000_000_000_000_000
        return "\(ms) ms"
    }

    private static func size(_ bytes: Int) -> String {
        bytes < 1024 ? "\(bytes) B" : String(format: "%.1f KB", Double(bytes) / 1024)
    }
    #endif
}
