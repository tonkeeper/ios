import Foundation
import BigInt
import TonSwift

public enum WKWBNetworkError: Error {
    case jsonDecode
    case emptyData
}

public typealias WKWBNetworkResponse = Any
public protocol WKWBNetworkInput: Encodable {}

public struct WKWBNetworkRequest<Input: WKWBNetworkInput, Response: WKWBNetworkResponse> {
    var urlPath: String
    var url: URL?
    var input: Input?
}

public extension WKWBNetworkInput {
    func asJson() -> [String: Any] {
        if let data = try? JSONEncoder().encode(self),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]  {
            return json
        }
        return [:]
    }
}

public enum WKWBNetworkRequestBuilder {}

// MARK: - createStakingTransactionBoc

public extension WKWBNetworkRequestBuilder {
    struct CreateStakingTransactionBocInput: WKWBNetworkInput {
        let POOL_ADDRESS: String
        let WALLET_ADDRESS: String
        let TOKEN_ADDRESS: String
        
        let AMOUNT: String
        let QUERY_ID: String
    }
    
    static func createStakingTransactionBoc(input: CreateStakingTransactionBocInput) -> WKWBNetworkRequest<CreateStakingTransactionBocInput, [String: Any?]> {
        WKWBNetworkRequest(urlPath: "createStakingTransactionBoc", input: input)
    }
}
