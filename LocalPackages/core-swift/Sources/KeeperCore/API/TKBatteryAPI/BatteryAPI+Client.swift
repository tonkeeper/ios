import Foundation
import HTTPTypes
import OpenAPIRuntime
import StreamURLSessionTransport
import TKBatteryAPI

private struct AuthHeaderMiddleware: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard
            let name = HTTPField.Name("X-TonConnect-Auth"),
            let rawField = request.headerFields[name],
            let encodedField = rawField.removingPercentEncoding
        else {
            return try await next(request, body, baseURL)
        }
        let request = {
            var request = request
            request.headerFields[name] = encodedField
            return request
        }()
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
        urlSession: URLSession
    ) async throws(InitFailure) {
        let basePath = await hostProvider.basePath
        guard let hostUrl = URL(string: basePath) else {
            throw .badHost(rawValue: basePath)
        }
        self = Client(
            serverURL: hostUrl,
            transport: StreamURLSessionTransport(
                urlSessionConfiguration: urlSession.configuration
            ),
            middlewares: [
                AuthHeaderMiddleware(),
            ]
        )
    }
}
