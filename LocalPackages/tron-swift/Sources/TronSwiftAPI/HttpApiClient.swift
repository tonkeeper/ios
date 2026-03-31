import Foundation
import TKLogging

struct HttpApiClient {
    var urlSession: URLSession
    var baseApiUrl: URL
    var isSuccessStatusCode: (Int) -> Bool
    private let middlewares: [any HttpApiMiddleware]

    init(
        urlSession: URLSession,
        baseApiUrl: URL,
        isSuccessStatusCode: @escaping (Int) -> Bool
    ) {
        self.urlSession = urlSession
        self.baseApiUrl = baseApiUrl
        self.isSuccessStatusCode = isSuccessStatusCode
        let rateLimiter = RequestRateLimiter(
            rps: 2
        )
        self.middlewares = [
            RetrierMiddleware(
                rateLimitRetryHandler: RequestRetrier(),
                rateLimiter: rateLimiter
            ),
            RateLimiterMiddleware(rateLimiter: rateLimiter),
        ]
    }
}

// MARK: - Decoding

extension HttpApiClient {
    enum DecodingFailure: Error {
        case typeMismatch(expected: String, found: String)
    }

    struct Decoder<T> {
        var decode: (Data) throws -> T

        init(_ impl: @escaping (Data) throws -> T) {
            self.decode = impl
        }

        static func defaultJsonSerialization() -> Self {
            Self { data in
                let anyObject = try JSONSerialization.jsonObject(with: data)
                guard let object = anyObject as? T else {
                    throw DecodingFailure.typeMismatch(
                        expected: "\(T.self)",
                        found: "\(type(of: anyObject))"
                    )
                }
                return object
            }
        }
    }
}

extension HttpApiClient.Decoder where T: Decodable {
    static func defaultDecodable() -> Self {
        Self { data in
            try JSONDecoder().decode(T.self, from: data)
        }
    }
}

// MARK: - Encoding

extension HttpApiClient {
    struct Encoder<T> {
        var encode: (T) throws -> Data

        init(_ impl: @escaping (T) throws -> Data) {
            self.encode = impl
        }

        static func defaultJsonSerialization() -> Self {
            Self { value in
                try JSONSerialization.data(withJSONObject: value)
            }
        }
    }
}

extension HttpApiClient.Encoder where T: Encodable {
    static func defaultEncodable() -> Self {
        Self { value in
            try JSONEncoder().encode(value)
        }
    }
}

// MARK: - Transport

extension HttpApiClient {
    func post<Request, Response>(
        endpoint: String,
        request: Request,
        encoder: Encoder<Request>,
        decoder: Decoder<Response>
    ) async throws(TronApi.Error) -> Response {
        try await post(
            endpoint: endpoint,
            request: request,
            responseType: Response.self,
            encoder: encoder,
            decoder: decoder
        )
    }

    func post<Request, Response>(
        endpoint: String,
        request: Request,
        responseType: Response.Type,
        encoder: Encoder<Request>,
        decoder: Decoder<Response>
    ) async throws(TronApi.Error) -> Response {
        let logTag = "http api post"
        let logExtraInfo = [
            "endpoint": endpoint,
            "requestId": UUID().uuidString,
        ]
        Log.tron.d("\(logTag) started", extraInfo: logExtraInfo)
        let urlRequest: URLRequest
        do {
            urlRequest = try {
                var urlRequest = URLRequest(
                    url: baseApiUrl.appendingPathComponent(endpoint)
                )
                urlRequest.httpMethod = "POST"
                urlRequest.httpBody = try encoder.encode(request)
                return urlRequest
            }()
        } catch {
            Log.tron.w("\(logTag) failed", extraInfo: [
                "failureReason": "invalid request: \(error)",
            ].reduce(into: logExtraInfo) { $0[$1.key] = $1.value })
            throw .invalidRequest
        }
        return try await process(
            urlRequest: urlRequest,
            decoder: decoder,
            logTag: logTag,
            logExtraInfo: logExtraInfo
        )
    }

    func get<Response>(
        endpoint: String,
        params: [String: String],
        decoder: Decoder<Response>
    ) async throws(TronApi.Error) -> Response {
        try await get(
            endpoint: endpoint,
            params: params,
            responseType: Response.self,
            decoder: decoder
        )
    }

    func get<Response>(
        endpoint: String,
        params: [String: String],
        responseType: Response.Type,
        decoder: Decoder<Response>
    ) async throws(TronApi.Error) -> Response {
        let logTag = "http api get"
        let logExtraInfo = [
            "endpoint": endpoint,
            "requestId": UUID().uuidString,
        ]
        Log.tron.d(logTag, extraInfo: logExtraInfo)
        let path = baseApiUrl.appendingPathComponent(endpoint)
        let url = {
            var components = URLComponents(url: path, resolvingAgainstBaseURL: true)
            components?.queryItems = params.map { key, value in
                URLQueryItem(name: key, value: value)
            }
            return components?.url
        }()
        guard let url else {
            Log.tron.w("\(logTag) failed", extraInfo: [
                "failureReason": "failed to build url",
            ].reduce(into: logExtraInfo) { $0[$1.key] = $1.value })
            throw .invalidRequest
        }
        let urlRequest = {
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "GET"
            return urlRequest
        }()
        return try await process(
            urlRequest: urlRequest,
            decoder: decoder,
            logTag: logTag,
            logExtraInfo: logExtraInfo
        )
    }

    private func process<Response>(
        urlRequest: URLRequest,
        decoder: Decoder<Response>,
        logTag: String,
        logExtraInfo: [String: String]
    ) async throws(TronApi.Error) -> Response {
        let transportPayload = try await executeTransportRequest(
            urlRequest: urlRequest,
            logTag: logTag,
            logExtraInfo: logExtraInfo
        )

        guard let httpResponse = transportPayload.response as? HTTPURLResponse else {
            Log.tron.w("\(logTag) failed", extraInfo: [
                "failureReason": "response is not a http response",
            ].reduce(into: logExtraInfo) { $0[$1.key] = $1.value })
            throw .invalidResponse
        }

        guard isSuccessStatusCode(httpResponse.statusCode) else {
            Log.tron.w("\(logTag) failed", extraInfo: [
                "failureReason": "server error code \(httpResponse.statusCode)",
            ].reduce(into: logExtraInfo) { $0[$1.key] = $1.value })
            throw .serverError(statusCode: httpResponse.statusCode)
        }

        let response: Response
        do {
            response = try decoder.decode(transportPayload.data)
        } catch {
            Log.tron.w("\(logTag) failed", extraInfo: [
                "failureReason": "response decoding failed error: \(error)",
            ].reduce(into: logExtraInfo) { $0[$1.key] = $1.value })
            throw .invalidResponse
        }
        return response
    }

    private func executeTransportRequest(
        urlRequest: URLRequest,
        logTag: String,
        logExtraInfo: [String: String]
    ) async throws(TronApi.Error) -> HttpApiTransportPayload {
        let transportRequest = urlRequest

        let baseOperation: HttpApiTransportOperation = {
            do {
                let (data, response) = try await urlSession.data(for: transportRequest)
                return HttpApiTransportPayload(data: data, response: response)
            } catch {
                Log.tron.w("\(logTag) failed", extraInfo: [
                    "failureReason": "network error: \(error)",
                ].reduce(into: logExtraInfo) { $0[$1.key] = $1.value })
                throw TronApi.Error.networkError
            }
        }

        let operation = middlewares
            .reversed()
            .reduce(baseOperation) { next, middleware in
                {
                    try await middleware.execute(
                        request: transportRequest,
                        next: next
                    )
                }
            }

        do {
            return try await operation()
        } catch let error as TronApi.Error {
            throw error
        } catch {
            Log.tron.w("\(logTag) failed", extraInfo: [
                "failureReason": "middleware pipeline unexpected error: \(error)",
            ].reduce(into: logExtraInfo) { $0[$1.key] = $1.value })
            throw .invalidResponse
        }
    }
}
