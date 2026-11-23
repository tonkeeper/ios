import Foundation
import HTTPTypes
import OpenAPIRuntime
import StreamURLSessionTransport
import TKLogging
import TonAPI

public typealias EmulateMessageToWalletRequestParamsInner = TonAPI.Components.RequestBodies.EmulationBoc.JsonPayload.ParamsPayloadPayload

/// A TonAPI response outside 2xx, with its raw body: the gateway's 429, a migration 409 and
/// the error payloads the domain parses all arrive as this, whatever the operation declares.
struct TonAPIError: Error {
    let statusCode: Int
    let body: Data?
    let path: String?
}

extension TonAPIError {
    /// The `error` TonAPI puts in the body of a request it refused.
    var errorMessage: String? {
        guard let body,
              let errorBody = try? JSONDecoder().decode(ErrorBody.self, from: body),
              !errorBody.error.isEmpty
        else {
            return nil
        }
        return errorBody.error
    }

    private struct ErrorBody: Decodable {
        let error: String
    }
}

extension Error {
    /// The `TonAPIError` a generated-client call failed with, unwrapped from `ClientError`.
    var tonAPIError: TonAPIError? {
        self as? TonAPIError ?? (self as? ClientError)?.underlyingError as? TonAPIError
    }

    /// Unlike `localizedDescription`, reads the same in every device language, so analytics can group
    /// failures by it: TonAPI's status and `error` when it answered, the error's log description otherwise.
    /// The account ids and hashes in it, as in a failing URL, are left out of analytics.
    public var analyticsReason: String {
        guard let apiError = tonAPIError else {
            return ((self as? ClientError)?.underlyingError ?? self).logDescription.redactingAddresses
        }
        guard let message = apiError.errorMessage else {
            return "\(apiError.statusCode)"
        }
        return "\(apiError.statusCode) \(LogDescription.truncated(message, limit: LogDescription.defaultValueLimit))"
            .redactingAddresses
    }
}

struct TonAPIStatusMiddleware: ClientMiddleware {
    static let bodyCeiling = 1_048_576

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (response, responseBody) = try await next(request, body, baseURL)
        guard !(200 ..< 300).contains(response.status.code) else {
            return (response, responseBody)
        }
        var data: Data?
        if let responseBody {
            data = try await Data(collecting: responseBody, upTo: Self.bodyCeiling)
        }
        throw TonAPIError(statusCode: response.status.code, body: data, path: request.path)
    }
}

private struct TonAPIHeadersMiddleware: ClientMiddleware {
    let headers: [String: String]

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        for (name, value) in headers {
            guard let fieldName = HTTPField.Name(name) else { continue }
            request.headerFields[fieldName] = value
        }
        return try await next(request, body, baseURL)
    }
}

extension TonAPI.Client {
    init(serverURL: URL, apiKey: String, urlSession: URLSession, headers: [String: String] = [:]) {
        self.init(
            serverURL: serverURL,
            transport: URLSessionTransport(urlSession: urlSession),
            middlewares: .tonAPI(apiKey: apiKey, headers: headers)
        )
    }
}

extension [any ClientMiddleware] {
    static func tonAPI(apiKey: String, headers: [String: String] = [:]) -> Self {
        // Log the HTTP response before status validation turns it into an error.
        [TonAPIStatusMiddleware()] + .logged([
            TonAPIHeadersMiddleware(headers: ["Authorization": "Bearer \(apiKey)"].merging(headers) { _, header in header }),
        ], domain: .tonAPI)
    }
}
