import Foundation

struct HttpApiTransportPayload {
    let data: Data
    let response: URLResponse
}

typealias HttpApiTransportOperation = () async throws -> HttpApiTransportPayload

protocol HttpApiMiddleware {
    func execute(
        request: URLRequest,
        next: @escaping HttpApiTransportOperation
    ) async throws -> HttpApiTransportPayload
}
