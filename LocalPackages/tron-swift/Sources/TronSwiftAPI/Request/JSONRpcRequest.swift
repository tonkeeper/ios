import Foundation

public struct JSONRpcRequest {
    public let id = UUID().uuidString
    public let method: String
    public let params: [Any]

    public init(method: String, params: [Any]) {
        self.method = method
        self.params = params
    }

    func parameters() -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": id,
        ]
    }
}
