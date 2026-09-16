import Foundation
import OpenAPIRuntime
import StreamURLSessionTransport
import TKKandelabrAPI

extension TKKandelabrAPI.Client {
    enum InitFailure: Error {
        case badHost
    }

    init(
        hostProvider: APIHostProvider,
        urlSession: URLSession
    ) async throws(InitFailure) {
        let basePath = await hostProvider.basePath
        guard let hostURL = URL(string: basePath), !basePath.isEmpty else {
            throw .badHost
        }
        self = Client(
            serverURL: hostURL,
            transport: URLSessionTransport(urlSession: urlSession),
            middlewares: .logged()
        )
    }
}
