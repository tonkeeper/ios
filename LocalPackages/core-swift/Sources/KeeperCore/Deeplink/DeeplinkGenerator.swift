import BigInt
import Foundation
import TonSwift

public struct DeeplinkGenerator {
    public enum Error: Swift.Error {
        case failed
    }

    public func generateTransferDeeplink(
        with addressString: String,
        amount: BigUInt? = nil,
        comment: String? = nil,
        jettonAddress: Address? = nil
    ) throws -> String {
        var urlComponents = URLComponents()
        urlComponents.scheme = "ton"
        urlComponents.host = "transfer"
        urlComponents.path = "/\(addressString)"
        if let amount {
            urlComponents.queryItems?.append(URLQueryItem(name: "amount", value: amount.description))
        }
        if let comment {
            urlComponents.queryItems?.append(URLQueryItem(name: "text", value: comment))
        }
        guard let url = urlComponents.url else {
            throw Error.failed
        }
        return url.absoluteString
    }

    public func generateTonSignOpenDeeplink() -> TonsignDeeplink {
        .plain
    }

    public init() {}
}
