import Foundation

enum LoyaltyAPIError: Error {
    case badURL
    case badStatus(Int)
    case profileUnavailable
}

struct LoyaltyAPI: @unchecked Sendable {
    private static let basePath = "/keeper-loyalty/public-api/v1"

    private let configuration: Configuration
    private let urlSession: URLSession
    private let authorizationService: BatteryWebAuthorizationService
    private let userAgent: String

    init(
        configuration: Configuration,
        urlSession: URLSession,
        authorizationService: BatteryWebAuthorizationService,
        userAgent: String
    ) {
        self.configuration = configuration
        self.urlSession = urlSession
        self.authorizationService = authorizationService
        self.userAgent = userAgent
    }

    func profile(wallet: Wallet) async throws -> LoyaltyProfile {
        try await get("profile", query: [], wallet: wallet)
    }

    func rewardEstimate(wallet: Wallet, kind: String, volumeUsd: String) async throws -> String {
        let estimate: RewardEstimate = try await get(
            "reward-estimate",
            query: [URLQueryItem(name: "kind", value: kind), URLQueryItem(name: "volume_usd", value: volumeUsd)],
            wallet: wallet
        )
        return estimate.total
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem], wallet: Wallet) async throws -> T {
        let url = try await url(path: path, query: query)
        let authorization = try await authorizationService.authorization(for: wallet, expiredDeviceToken: nil)
        var (data, status) = try await send(url: url, authorization: authorization)
        if status == 401 {
            let recovered = try await authorizationService.authorization(
                for: wallet,
                expiredDeviceToken: authorization.deviceToken
            )
            (data, status) = try await send(url: url, authorization: recovered)
        }
        guard (200 ..< 300).contains(status) else {
            throw LoyaltyAPIError.badStatus(status)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func send(url: URL, authorization: BatteryWebAuthorization) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authorization.deviceToken)", forHTTPHeaderField: "Authorization")
        request.setValue(authorization.walletToken, forHTTPHeaderField: "X-Wallet-Authorization")
        request.setValue(authorization.walletId, forHTTPHeaderField: "X-Wallet-ID")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await urlSession.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private func url(path: String, query: [URLQueryItem]) async throws -> URL {
        let multichainURL = await configuration.multichainHost(network: .mainnet)
        var components = URLComponents()
        components.scheme = multichainURL.scheme
        components.host = multichainURL.host
        components.port = multichainURL.port
        components.path = "\(Self.basePath)/\(path)"
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else {
            throw LoyaltyAPIError.badURL
        }
        return url
    }
}

private struct RewardEstimate: Decodable {
    let total: String
}
