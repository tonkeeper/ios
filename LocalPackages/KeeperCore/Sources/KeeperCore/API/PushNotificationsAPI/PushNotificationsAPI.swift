import Foundation

public struct PushNotificationsAPI {
    @frozen public enum Error: Swift.Error {
        case incorrectURL
        case unexpectedStatusCode(Int)
    }

    struct Response: Decodable {
        let ok: Bool
    }

    private let urlSession: URLSession

    init(urlSession: URLSession) {
        self.urlSession = urlSession
    }

    /// Reject error statuses even when the body says `ok`.
    private func isOk(_ request: URLRequest) async throws -> Bool {
        try await JSONDecoder().decode(Response.self, from: validatedData(request)).ok
    }

    private func validatedData(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        if let statusCode = (response as? HTTPURLResponse)?.statusCode, !(200 ..< 300).contains(statusCode) {
            throw Error.unexpectedStatusCode(statusCode)
        }
        return data
    }

    public struct SubscribeData: Encodable {
        public struct Account: Encodable {
            public let address: String
            public init(address: String) {
                self.address = address
            }
        }

        public let token: String
        public let device: String
        public let accounts: [Account]
        public let locale: String
        public init(token: String, device: String, accounts: [Account], locale: String) {
            self.token = token
            self.device = device
            self.accounts = accounts
            self.locale = locale
        }
    }

    public func subscribeNotifications(subscribeData: SubscribeData) async throws -> Bool {
        guard var components = URLComponents(url: .host, resolvingAgainstBaseURL: true) else {
            throw Error.incorrectURL
        }
        components.path = "/v1/internal/pushes/plain/subscribe"
        guard let url = components.url else {
            throw Error.incorrectURL
        }

        let encoder = JSONEncoder()
        let httpBody = try encoder.encode(subscribeData)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = httpBody
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return try await isOk(urlRequest)
    }

    public struct UnsubscribeData: Encodable {
        public struct Account: Encodable {
            public let address: String
            public init(address: String) {
                self.address = address
            }
        }

        public let device: String
        public let accounts: [Account]
        public init(device: String, accounts: [Account]) {
            self.device = device
            self.accounts = accounts
        }
    }

    public func unsubscribeNotifications(unsubscribeData: UnsubscribeData) async throws -> Bool {
        guard var components = URLComponents(url: .host, resolvingAgainstBaseURL: true) else {
            throw Error.incorrectURL
        }
        components.path = "/unsubscribe"
        guard let url = components.url else {
            throw Error.incorrectURL
        }

        let encoder = JSONEncoder()
        let httpBody = try encoder.encode(unsubscribeData)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = httpBody
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return try await isOk(urlRequest)
    }

    public struct DappSubscribeData {
        public let token: String
        public let appURL: String
        public let account: String
        public let tonProof: String
        public let sessionId: String?
        public let commercial: Bool
        public let silent: Bool
        public init(
            token: String,
            appURL: String,
            account: String,
            tonProof: String,
            sessionId: String?,
            commercial: Bool,
            silent: Bool
        ) {
            self.token = token
            self.appURL = appURL
            self.account = account
            self.tonProof = tonProof
            self.sessionId = sessionId
            self.commercial = commercial
            self.silent = silent
        }
    }

    public func subscribeDappNotifications(subscribeData: DappSubscribeData) async throws -> Bool {
        guard var components = URLComponents(url: .host, resolvingAgainstBaseURL: true) else {
            throw Error.incorrectURL
        }
        components.path = "/v1/internal/pushes/tonconnect"
        guard let url = components.url else {
            throw Error.incorrectURL
        }

        var bodyJson: [String: Any] = [
            "app_url": subscribeData.appURL,
            "account": subscribeData.account,
            "firebase_token": subscribeData.token,
            "commercial": subscribeData.commercial,
            "silent": subscribeData.silent,
        ]
        if let sessionId = subscribeData.sessionId {
            bodyJson["session_id"] = sessionId
        }
        let bodyData = try? JSONSerialization.data(withJSONObject: bodyJson)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = bodyData
        urlRequest.setValue(subscribeData.tonProof, forHTTPHeaderField: "X-TonConnect-Auth")
        urlRequest.setValue("close", forHTTPHeaderField: "Connection")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return try await isOk(urlRequest)
    }

    public struct DappUnsubscribeData {
        public let token: String
        public let appURL: String
        public let account: String
        public let tonProof: String

        public init(
            token: String,
            appURL: String,
            account: String,
            tonProof: String
        ) {
            self.token = token
            self.appURL = appURL
            self.account = account
            self.tonProof = tonProof
        }
    }

    /// Toggles use POST; only DELETE removes a dApp subscription.
    public func unsubscribeDappNotifications(unsubscribeData: DappUnsubscribeData) async throws -> Bool {
        guard var components = URLComponents(url: .host, resolvingAgainstBaseURL: true) else {
            throw Error.incorrectURL
        }
        components.path = "/v1/internal/pushes/tonconnect"
        components.queryItems = [
            URLQueryItem(name: "firebase_token", value: unsubscribeData.token),
            URLQueryItem(name: "app_url", value: unsubscribeData.appURL),
            URLQueryItem(name: "account", value: unsubscribeData.account),
        ]
        guard let url = components.url else {
            throw Error.incorrectURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue(unsubscribeData.tonProof, forHTTPHeaderField: "X-TonConnect-Auth")
        urlRequest.setValue("close", forHTTPHeaderField: "Connection")

        _ = try await validatedData(urlRequest)
        return true
    }
}

private extension URL {
    static var host: URL {
        URL(string: "https://keeper.tonapi.io")!
    }
}
