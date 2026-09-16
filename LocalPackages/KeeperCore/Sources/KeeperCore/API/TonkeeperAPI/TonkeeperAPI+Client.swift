import Foundation
import StreamURLSessionTransport
import TKTonkeeperAPI

extension TKTonkeeperAPI.Client {
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
            transport: URLSessionTransport(urlSession: urlSession),
            middlewares: .logged()
        )
    }
}
