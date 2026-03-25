import CoreComponents
import Foundation

public struct WebAPIResponse: Encodable {
    public let body: String
    public let ok: Bool
    public let status: Int
    public let statusText: String
    public let type: String
    public let headers: [String: String]
    public let redirected: Bool
    public let url: URL
}

public protocol DappFetchService {
    func fetch(_ url: String, params: [String: Any]?) async throws -> Data
}

final class DappFetchServiceImplementation: DappFetchService {
    private let apiProvider: APIProvider

    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }

    func fetch(_ url: String, params: [String: Any]?) async throws -> Data {
        let (data, response) = try await apiProvider.api(.mainnet).tonapiFetch(url: url, options: params)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        let ok = (200 ... 299).contains(httpResponse.statusCode)
        let status = httpResponse.statusCode
        let statusText = HTTPURLResponse.localizedString(forStatusCode: status)
        let type = status == 0 ? "error" : "cors"
        let headers = httpResponse.allHeaderFields.compactMapValues { $0 as? String } as! [String: String]
        let redirected = httpResponse.url?.absoluteString != url
        let url = httpResponse.url ?? URL(string: url)!

        let webAPIResponse = WebAPIResponse(
            body: body,
            ok: ok,
            status: status,
            statusText: statusText,
            type: type,
            headers: headers,
            redirected: redirected,
            url: url
        )

        let encoder = JSONEncoder()
        return try encoder.encode(webAPIResponse)
    }
}
