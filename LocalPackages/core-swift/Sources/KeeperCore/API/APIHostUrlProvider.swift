import Foundation
import HTTPTypes
import OpenAPIRuntime
import TonAPI

final class APIHostUrlProvider: ClientMiddleware {
    func intercept(
        _ request: HTTPTypes.HTTPRequest,
        body: OpenAPIRuntime.HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL)
        async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
    )
        async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
    {
        let url = URL(string: "https://keeper.tonapi.io") ?? baseURL
        return try await next(request, body, url)
    }
}
