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
    private let bodyLoggedOperations: Set<String>

    init(
        domain: LogDomain = .api,
        slowRequestThreshold: TimeInterval = 3,
        maxLoggedResponseBody: Int = 4096,
        bodyLoggedOperations: Set<String> = []
    ) {
        self.domain = domain
        self.slowRequestThreshold = slowRequestThreshold
        self.maxLoggedResponseBody = maxLoggedResponseBody
        self.bodyLoggedOperations = bodyLoggedOperations
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
        let message: (String, Bool) -> String = { outcome, withValues in
            let path = (withValues ? request.loggedPathWithValues : request.loggedPath) ?? ""
            return "\(operationID) \(request.method.rawValue) \(path) → \(outcome) in \(startedAt.pretty.msSinceNow)ms"
        }

        let logsBodies = bodyLoggedOperations.contains(operationID)
        var requestBody = body
        var loggedRequestBody: String?
        if logsBodies {
            (loggedRequestBody, requestBody) = try await captured(
                body,
                headers: request.headerFields,
                limit: maxLoggedResponseBody,
                requireContentLength: false
            )
        }

        let response: HTTPResponse
        let responseBody: HTTPBody?
        do {
            (response, responseBody) = try await next(request, requestBody, baseURL)
        } catch {
            domain.failure(
                message("failed", false),
                error: error,
                extraInfo: info(host: baseURL, requestBody: loggedRequestBody)
            )
            throw error
        }

        let status = response.status.code
        let outcome = Self.requestId(in: response.headerFields).map { "\(status) \($0)" } ?? "\(status)"
        guard status >= 400 else {
            if Date().timeIntervalSince(startedAt) >= slowRequestThreshold {
                domain.i("\(message(outcome, false)) - slow")
            } else if !logsBodies {
                domain.d(message(outcome, true))
            }
            guard logsBodies else {
                return (response, responseBody)
            }
            let loggedBody: String?
            let forwardedBody: HTTPBody?
            do {
                (loggedBody, forwardedBody) = try await captured(
                    responseBody,
                    headers: response.headerFields,
                    limit: maxLoggedResponseBody,
                    requireContentLength: false
                )
            } catch {
                domain.d(
                    message(outcome, true),
                    error: error,
                    extraInfo: info(requestBody: loggedRequestBody, responseBody: "<unreadable>")
                )
                throw error
            }
            domain.d(
                message(outcome, true),
                extraInfo: info(requestBody: loggedRequestBody, responseBody: loggedBody ?? "<not captured>")
            )
            return (response, forwardedBody)
        }

        let loggedBody: String?
        let forwardedBody: HTTPBody?
        do {
            (loggedBody, forwardedBody) = try await captured(responseBody, headers: response.headerFields, limit: 512)
        } catch {
            // The status is the point of this line, so it goes out even when the body could not
            // be read — and the read failure travels on to the caller as it would have anyway.
            domain.w(
                message(outcome, false),
                error: error,
                extraInfo: info(host: baseURL, requestBody: loggedRequestBody, responseBody: "<unreadable>")
            )
            throw error
        }
        domain.w(
            message(outcome, false),
            extraInfo: info(host: baseURL, requestBody: loggedRequestBody, responseBody: loggedBody ?? "<not captured>")
        )
        return (response, forwardedBody)
    }

    private func info(host: URL? = nil, requestBody: String?, responseBody: String? = nil) -> [String: String] {
        var info = [String: String]()
        if let host {
            info["host"] = host.host ?? ""
        }
        if let requestBody {
            info["requestBody"] = requestBody
        }
        if let responseBody {
            info["responseBody"] = responseBody
        }
        return info
    }

    private static func requestId(in headers: HTTPFields) -> String? {
        let ids = headers.compactMap { field -> String? in
            let name = field.name.rawName.lowercased()
            guard name == "cf-ray" || name.hasSuffix("request-id") || name.hasSuffix("trace-id") else {
                return nil
            }
            return "\(name)=\(field.value)"
        }
        return ids.isEmpty ? nil : ids.joined(separator: " ")
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
        headers: HTTPFields,
        limit: Int,
        requireContentLength: Bool = true
    ) async throws -> (logged: String?, forwarded: HTTPBody?) {
        guard let body, headers[.contentType]?.contains("json") == true else {
            return (nil, body)
        }
        if requireContentLength {
            guard let contentLength = headers[.contentLength].flatMap(Int.init),
                  contentLength > 0,
                  contentLength <= maxLoggedResponseBody
            else {
                return (nil, body)
            }
        }

        let data = try await Data(collecting: body, upTo: Self.collectionCeiling)
        let text = LogDescription.truncated(String(decoding: data, as: UTF8.self), limit: limit)
        return (text, HTTPBody(data))
    }

    fileprivate static let collectionCeiling = 10 * 1024 * 1024
}

extension ClientError {
    /// What a 2xx response said when the generated client could not decode it. Readable only for
    /// an operation the middleware buffers (its `bodies`): any other body is single-pass, and the
    /// decoder has already spent it.
    func undecodedResponseBody(limit: Int = 4096) async -> String? {
        guard response?.status.kind == .successful,
              let responseBody,
              let data = try? await Data(collecting: responseBody, upTo: APILoggingMiddleware.collectionCeiling)
        else {
            return nil
        }
        return LogDescription.truncated(String(decoding: data, as: UTF8.self), limit: limit)
    }
}
