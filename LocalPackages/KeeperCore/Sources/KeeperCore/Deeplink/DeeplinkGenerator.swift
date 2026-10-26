import BigInt
import Foundation
import TonSwift

public struct DeeplinkGenerator {
    @frozen public enum Error: Swift.Error {
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

        var queryItems: [URLQueryItem] = []
        if let amount {
            queryItems.append(URLQueryItem(name: "amount", value: amount.description))
        }
        if let comment {
            queryItems.append(URLQueryItem(name: "text", value: comment))
        }
        if let jettonAddress {
            queryItems.append(URLQueryItem(name: "jetton", value: jettonAddress.toString()))
        }
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
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
