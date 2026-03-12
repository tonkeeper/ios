import Foundation

public enum JSONRpcResponse {
    public struct SuccessResponse {
        public let version: String
        public let id: String
        public let result: Any?

        enum Error: Swift.Error {
            case invalidVersion
            case invalidId
            case noResult
        }

        init(json: [String: Any]) throws {
            guard let version = json["jsonrpc"] as? String else {
                throw Error.invalidVersion
            }
            guard let id = json["id"] as? String else {
                throw Error.invalidId
            }
            guard let result = json["result"] else {
                throw Error.noResult
            }

            self.version = version
            self.id = id
            self.result = result
        }
    }

    public struct ErrorResponse {
        public let version: String
        public let id: String
        public let error: RPCError

        enum Error: Swift.Error {
            case invalidVersion
            case invalidId
            case invalidError
        }

        init(json: [String: Any]) throws {
            guard let version = json["jsonrpc"] as? String else {
                throw Error.invalidVersion
            }
            guard let id = json["id"] as? String else {
                throw Error.invalidId
            }
            guard let error = json["error"] as? [String: Any] else {
                throw Error.invalidError
            }
            self.version = version
            self.id = id
            self.error = try RPCError(json: error)
        }
    }

    public struct RPCError {
        public let code: Int
        public let message: String
        public let data: Any?

        enum Error: Swift.Error {
            case invalidCode
            case invalidMessage
        }

        init(json: [String: Any]) throws {
            guard let code = json["code"] as? Int else {
                throw Error.invalidCode
            }
            guard let message = json["message"] as? String else {
                throw Error.invalidMessage
            }
            self.code = code
            self.message = message
            self.data = json["data"]
        }
    }

    case success(SuccessResponse)
    case error(ErrorResponse)

    public enum Error: Swift.Error {
        case invalidResponse
    }

    init(responseData: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw Error.invalidResponse
        }

        if let successResponse = try? SuccessResponse(json: json) {
            self = .success(successResponse)
            return
        }

        if let errorResponse = try? ErrorResponse(json: json) {
            self = .error(errorResponse)
            return
        }

        throw Error.invalidResponse
    }
}
