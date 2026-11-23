import Foundation
import OpenAPIRuntime
import StreamURLSessionTransport
import TKTonstakersAPI

extension TKTonstakersAPI.Client {
    /// The spec lists no servers; its paths carry the `/api/v1` prefix.
    static let tonstakersHost = URL(string: "https://api.tonstakers.com")!

    init(
        urlSession: URLSession,
        middlewares: [any ClientMiddleware]
    ) {
        self = Client(
            serverURL: Self.tonstakersHost,
            transport: URLSessionTransport(urlSession: urlSession),
            middlewares: .logged(middlewares)
        )
    }
}
