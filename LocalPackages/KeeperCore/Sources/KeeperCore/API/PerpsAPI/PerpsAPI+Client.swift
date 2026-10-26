import Foundation
import OpenAPIRuntime
import StreamURLSessionTransport
import TKLogging
import TKPerpsAPI

extension TKPerpsAPI.Client {
    enum InitFailure: Error {
        case badHost(rawValue: String)
    }

    init(
        hostURL: URL,
        urlSession: URLSession,
        middlewares: [any ClientMiddleware]
    ) throws(InitFailure) {
        guard let host = hostURL.host, !host.isEmpty else {
            throw .badHost(rawValue: hostURL.absoluteString)
        }
        let serverURL: URL
        do {
            serverURL = try Servers.server1(host: host)
        } catch {
            throw .badHost(rawValue: host)
        }
        self = Client(
            serverURL: serverURL,
            configuration: OpenAPIRuntime.Configuration(dateTranscoder: MultichainDateTranscoder()),
            transport: URLSessionTransport(urlSession: urlSession),
            middlewares: .logged(
                middlewares,
                domain: .perps,
                bodies: ["getPositionState", "sendTransactions", "getOrder", "getOpenPosition", "getTradingScreen", "quoteDeposit"]
            )
        )
    }
}
