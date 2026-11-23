import Foundation
import OpenAPIRuntime
import StreamURLSessionTransport
import TKEarnAPI

extension TKEarnAPI.Client {
    /// The spec's paths carry the `/keeper-earn` service prefix, so the configured host is the server.
    init(
        host: URL,
        urlSession: URLSession,
        middlewares: [any ClientMiddleware]
    ) {
        self = Client(
            serverURL: host,
            configuration: OpenAPIRuntime.Configuration(dateTranscoder: MultichainDateTranscoder()),
            transport: URLSessionTransport(urlSession: urlSession),
            middlewares: .logged(middlewares)
        )
    }
}
