import Foundation

public struct PushNotificationsAPI {
    public enum Error: Swift.Error {
        case incorrectURL
    }

    struct Response: Decodable {
        let ok: Bool
    }

    private let urlSession: URLSession

    init(urlSession: URLSession) {
        self.urlSession = urlSession
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

        let (data, _) = try await urlSession.data(for: urlRequest)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.ok
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

        let (data, _) = try await urlSession.data(for: urlRequest)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.ok
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

        let (data, _) = try await urlSession.data(for: urlRequest)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.ok
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

    public func unsubscribeDappNotifications(unsubscribeData: DappUnsubscribeData) async throws -> Bool {
        guard var components = URLComponents(url: .host, resolvingAgainstBaseURL: true) else {
            throw Error.incorrectURL
        }
        components.path = "/v1/internal/pushes/tonconnect"
        guard let url = components.url else {
            throw Error.incorrectURL
        }

        let bodyJson: [String: Any] = [
            "app_url": unsubscribeData.appURL,
            "account": unsubscribeData.account,
            "firebase_token": unsubscribeData.token,
            "commercial": false,
            "silent": true,
        ]
        let bodyData = try? JSONSerialization.data(withJSONObject: bodyJson)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = bodyData
        urlRequest.setValue(unsubscribeData.tonProof, forHTTPHeaderField: "X-TonConnect-Auth")
        urlRequest.setValue("close", forHTTPHeaderField: "Connection")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await urlSession.data(for: urlRequest)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.ok
    }
}

private extension URL {
    static var host: URL {
        URL(string: "https://keeper.tonapi.io")!
    }
}
