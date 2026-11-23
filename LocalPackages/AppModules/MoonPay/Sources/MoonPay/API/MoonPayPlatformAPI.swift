import Foundation

/// Thin client for the Platform API calls a host app makes directly.
public struct MoonPayPlatformAPI: Sendable {
    public let environment: MoonPayEnvironment
    private let urlSession: URLSession

    public init(environment: MoonPayEnvironment, urlSession: URLSession = .shared) {
        self.environment = environment
        self.urlSession = urlSession
    }

    /// Sandbox and test tooling only. The secret key is a server credential: a shipping build gets
    /// its session from Tonkeeper's backend, never from here.
    public func createSession(secretKey: String, request: MoonPayCreateSessionRequest) async throws -> MoonPaySessionToken {
        let response: MoonPaySessionResponse = try await perform(makeRequest(
            .post,
            path: "/platform/v1/sessions",
            headers: ["X-Api-Key": secretKey],
            body: request
        ))
        return MoonPaySessionToken(rawValue: response.sessionToken)
    }

    public func buyQuote(accessToken: String, request: MoonPayBuyQuoteRequest) async throws -> MoonPayBuyQuote {
        let (response, httpResponse): (MoonPayBuyQuoteResponse, HTTPURLResponse) = try await performWithResponse(makeRequest(
            .post,
            path: "/platform/v1/quotes/buy",
            headers: ["Authorization": "Bearer \(accessToken)"],
            body: request
        ))
        var quote = response.data
        if let expiresAt = quote.expiresAt, let serverDate = Self.serverDate(of: httpResponse) {
            quote.localExpiresAt = Date().addingTimeInterval(expiresAt.timeIntervalSince(serverDate))
        }
        return quote
    }

    private static func serverDate(of response: HTTPURLResponse) -> Date? {
        guard let value = response.value(forHTTPHeaderField: "Date") else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value)
    }

    /// Payment method types available to the connected customer plus the methods stored on the
    /// account. Customer scoped: it takes the access token of an active connection, never the
    /// secret key. `currency` (ISO 4217) narrows the configurations to one fiat currency.
    public func paymentMethods(accessToken: String, currency: String? = nil) async throws -> MoonPayPaymentMethods {
        let response: MoonPayPaymentMethodsResponse = try await perform(makeRequest(
            .get,
            path: "/platform/v1/payment-methods",
            query: currency.map { [URLQueryItem(name: "currency", value: $0)] } ?? [],
            headers: ["Authorization": "Bearer \(accessToken)"]
        ))
        return response.data
    }

    /// Removes a stored payment method from the connected customer's account. Answers `204`.
    public func deletePaymentMethod(accessToken: String, id: String) async throws {
        _ = try await send(makeRequest(
            .delete,
            path: "/platform/v1/payment-methods/\(id)",
            headers: ["Authorization": "Bearer \(accessToken)"]
        ))
    }

    /// One page of the assets MoonPay can sell. `source` narrows it to CeFi assets or DeFi tokens.
    public func assets(
        accessToken: String,
        source: MoonPayAssetSource? = nil,
        code: String? = nil,
        cursor: String? = nil,
        limit: Int = 50
    ) async throws -> MoonPayAssetsPage {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let source { query.append(URLQueryItem(name: "source", value: source.rawValue)) }
        if let code { query.append(URLQueryItem(name: "code", value: code)) }
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        let response: MoonPayAssetsResponse = try await perform(makeRequest(
            .get,
            path: "/platform/v1/assets",
            query: query,
            headers: ["Authorization": "Bearer \(accessToken)"]
        ))
        return MoonPayAssetsPage(assets: response.data, nextCursor: response.pageInfo?.nextCursor)
    }

    /// Customer scoped, like `paymentMethods`: takes the access token of an active connection.
    public func transaction(accessToken: String, id: String) async throws -> MoonPayTransactionDetails {
        let response: MoonPayTransactionResponse = try await perform(makeRequest(
            .get,
            path: "/platform/v1/transactions/\(id)",
            headers: ["Authorization": "Bearer \(accessToken)"]
        ))
        return response.data
    }

    /// The first page of the customer's transactions created at or after `startDate`. Customer
    /// scoped: it takes the access token of an active connection.
    public func transactions(accessToken: String, startDate: Date, limit: Int = 50) async throws -> [MoonPayTransactionDetails] {
        let response: MoonPayTransactionsResponse = try await perform(makeRequest(
            .get,
            path: "/platform/v1/transactions",
            query: [
                URLQueryItem(name: "startDate", value: MoonPayJSONCoding.formatISO8601(startDate)),
                URLQueryItem(name: "limit", value: String(limit)),
            ],
            headers: ["Authorization": "Bearer \(accessToken)"]
        ))
        return response.data
    }

    private enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case delete = "DELETE"
    }

    private func makeRequest(
        _ method: HTTPMethod,
        path: String,
        query: [URLQueryItem] = [],
        headers: [String: String]
    ) throws -> URLRequest {
        guard var components = URLComponents(url: environment.apiBaseURL, resolvingAgainstBaseURL: false) else {
            throw MoonPayAPIError.invalidURL
        }
        components.path = path
        // An empty array still produces a trailing "?".
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else { throw MoonPayAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }

    private func makeRequest<Body: Encodable>(
        _ method: HTTPMethod,
        path: String,
        headers: [String: String],
        body: Body
    ) throws -> URLRequest {
        var request = try makeRequest(method, path: path, headers: headers)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try MoonPayJSONCoding.makeEncoder().encode(body)
        } catch {
            throw MoonPayAPIError.encoding(error)
        }
        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        try await performWithResponse(request).0
    }

    private func performWithResponse<Response: Decodable>(_ request: URLRequest) async throws -> (Response, HTTPURLResponse) {
        let (data, httpResponse) = try await send(request)
        do {
            return try (MoonPayJSONCoding.makeDecoder().decode(Response.self, from: data), httpResponse)
        } catch {
            throw MoonPayAPIError.decoding(error)
        }
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw MoonPayAPIError.transport(error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MoonPayAPIError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let serverError = try? MoonPayJSONCoding.makeDecoder().decode(MoonPayServerError.self, from: data)
            if httpResponse.statusCode == 429 {
                throw MoonPayAPIError.rateLimited(body: serverError)
            }
            throw MoonPayAPIError.http(status: httpResponse.statusCode, body: serverError)
        }
        return (data, httpResponse)
    }
}
