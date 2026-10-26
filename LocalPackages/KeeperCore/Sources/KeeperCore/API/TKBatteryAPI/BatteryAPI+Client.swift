import Foundation
import HTTPTypes
import OpenAPIRuntime
import StreamURLSessionTransport
import TKBatteryAPI

/// Attaches the credentials the battery reads.
///
/// The schema declares them as security schemes — `deviceJWT` as `Authorization: Bearer`,
/// `tonConnectAuth`, `walletAuth` and `xWalletId` as their own headers — which the generator turns
/// into no operation parameters at all, so they are set here instead of per call site.
struct BatteryAuthHeaderMiddleware: ClientMiddleware {
    private let authorization: BatteryAuthorization

    init(authorization: BatteryAuthorization) {
        self.authorization = authorization
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        for field in authorization.httpHeaderFields {
            guard let name = HTTPField.Name(field.name) else {
                continue
            }
            request.headerFields[name] = field.value
        }
        return try await next(request, body, baseURL)
    }
}

private struct ExtraHeadersMiddleware: ClientMiddleware {
    private let headers: [String: String]

    init(headers: [String: String]) {
        self.headers = headers
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard !headers.isEmpty else {
            return try await next(request, body, baseURL)
        }
        var request = request
        for (name, value) in headers {
            guard let fieldName = HTTPField.Name(name) else { continue }
            request.headerFields[fieldName] = value
        }
        return try await next(request, body, baseURL)
    }
}

extension TKBatteryAPI.Client {
    enum InitFailure: Error {
        case badHost(
            rawValue: String
        )
    }

    init(
        hostProvider: APIHostProvider,
        urlSession: URLSession,
        authorization: BatteryAuthorization = .none,
        extraHeaders: [String: String] = [:]
    ) async throws(InitFailure) {
        let basePath = await hostProvider.basePath
        guard let hostUrl = URL(string: basePath) else {
            throw .badHost(rawValue: basePath)
        }
        var middlewares: [any ClientMiddleware] = .logged([
            BatteryAuthHeaderMiddleware(authorization: authorization),
        ])
        if !extraHeaders.isEmpty {
            middlewares.append(ExtraHeadersMiddleware(headers: extraHeaders))
        }
        self = Client(
            serverURL: hostUrl,
            configuration: OpenAPIRuntime.Configuration(dateTranscoder: MultichainDateTranscoder()),
            transport: URLSessionTransport(urlSession: urlSession),
            middlewares: middlewares
        )
    }
}
