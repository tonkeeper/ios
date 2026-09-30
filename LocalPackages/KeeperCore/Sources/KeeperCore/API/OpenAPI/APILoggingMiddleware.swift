import Foundation
import HTTPTypes
import OpenAPIRuntime
import TKLogging

/// Records the generated-client calls — a failure, an error status or an unusual wait as a
/// warning or notice, carrying the request, the status and the server's error body; everything
/// else at debug, which a release build's severity drops. Everything downstream — the per-API
/// error enums, the view models — narrows what it keeps, so this is the only place the whole
/// picture exists.
struct APILoggingMiddleware: ClientMiddleware {
    private let domain: LogDomain
    private let slowRequestThreshold: TimeInterval
    private let maxLoggedResponseBody: Int

    init(
        domain: LogDomain = .api,
        slowRequestThreshold: TimeInterval = 3,
        maxLoggedResponseBody: Int = 4096
    ) {
        self.domain = domain
        self.slowRequestThreshold = slowRequestThreshold
        self.maxLoggedResponseBody = maxLoggedResponseBody
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let startedAt = Date()
        // Built on demand: the common path logs nothing, and rendering the path costs more than
        // the branch that discards it.
        let message: (String) -> String = { outcome in
            let path = request.loggedPath ?? ""
            return "\(operationID) \(request.method.rawValue) \(path) → \(outcome) in \(startedAt.pretty.msSinceNow)ms"
        }

        let response: HTTPResponse
        let responseBody: HTTPBody?
        do {
            (response, responseBody) = try await next(request, body, baseURL)
        } catch {
            domain.failure(
                message("failed"),
                error: error,
                extraInfo: ["host": baseURL.host ?? ""]
            )
            throw error
        }

        let status = response.status.code
        guard status >= 400 else {
            if Date().timeIntervalSince(startedAt) >= slowRequestThreshold {
                domain.i("\(message("\(status)")) - slow")
            } else {
                domain.d(message("\(status)"))
            }
            return (response, responseBody)
        }

        let loggedBody: String?
        let forwardedBody: HTTPBody?
        do {
            (loggedBody, forwardedBody) = try await captured(responseBody, of: response)
        } catch {
            // The status is the point of this line, so it goes out even when the body could not
            // be read — and the read failure travels on to the caller as it would have anyway.
            domain.w(
                message("\(status)"),
                error: error,
                extraInfo: info(baseURL: baseURL, body: "<unreadable>")
            )
            throw error
        }
        domain.w(
            message("\(status)"),
            extraInfo: info(baseURL: baseURL, body: loggedBody ?? "<not captured>")
        )
        return (response, forwardedBody)
    }

    private func info(baseURL: URL, body: String) -> [String: String] {
        ["host": baseURL.host ?? "", "responseBody": body]
    }

    /// `HTTPBody` is single-pass, so the error payload can only be logged by buffering it and
    /// handing a fresh body downstream. `Content-Length` decides whether to buffer at all: a
    /// streamed or large response is forwarded untouched rather than risking the caller's decoding.
    ///
    /// The collection ceiling is far above that gate on purpose. A compressed response declares
    /// its compressed size, so a body admitted by the gate can still decode to several times it —
    /// and a ceiling that tripped there would fail a request that used to succeed.
    private func captured(
        _ body: HTTPBody?,
        of response: HTTPResponse
    ) async throws -> (logged: String?, forwarded: HTTPBody?) {
        guard let body,
              response.headerFields[.contentType]?.contains("json") == true,
              let contentLength = response.headerFields[.contentLength].flatMap(Int.init),
              contentLength > 0,
              contentLength <= maxLoggedResponseBody
        else {
            return (nil, body)
        }

        let data = try await Data(collecting: body, upTo: Self.collectionCeiling)
        let text = LogDescription.truncated(String(decoding: data, as: UTF8.self), limit: 512)
        return (text, HTTPBody(data))
    }

    private static let collectionCeiling = 10 * 1024 * 1024
}
