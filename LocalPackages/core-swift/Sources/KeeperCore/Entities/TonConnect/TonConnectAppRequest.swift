import Foundation
import TonSwift

enum AppRequestError: Swift.Error {
    case unknownMethod
    case noParams
}

public extension TonConnect {
    struct SendTransactionRequest: Decodable {
        public let params: [SignRawRequest]
        public let id: String

        public init(params: [SignRawRequest], id: String) {
            self.params = params
            self.id = id
        }
    }

    struct SignDataRequest: Decodable {
        public let params: TonConnectSignDataPayload
        public let id: String

        public init(params: TonConnectSignDataPayload, id: String) {
            self.params = params
            self.id = id
        }
    }

    enum AppRequest: Decodable {
        case sendTransaction(SendTransactionRequest)
        case signData(SignDataRequest)

        enum CodingKeys: String, CodingKey {
            case method
            case params
            case id
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let method = try container.decode(String.self, forKey: .method)
            let id = try container.decode(String.self, forKey: .id)

            switch method {
            case "sendTransaction":
                let paramsArray = try container.decode([String].self, forKey: .params)
                let jsonDecoder = JSONDecoder()
                let signRawRequests = paramsArray.compactMap { (string: String) -> SignRawRequest? in
                    guard let data = string.data(using: .utf8) else { return nil }
                    return try? jsonDecoder.decode(SignRawRequest.self, from: data)
                }
                self = .sendTransaction(SendTransactionRequest(params: signRawRequests, id: id))

            case "signData":
                let paramsArray = try container.decode([String].self, forKey: .params)
                let jsonDecoder = JSONDecoder()

                guard let param = paramsArray[0].data(using: .utf8) else {
                    throw AppRequestError.noParams
                }
                let params = try jsonDecoder.decode(TonConnectSignDataPayload.self, from: param)
                self = .signData(SignDataRequest(params: params, id: id))

            default:
                throw AppRequestError.unknownMethod
            }
        }
    }
}
