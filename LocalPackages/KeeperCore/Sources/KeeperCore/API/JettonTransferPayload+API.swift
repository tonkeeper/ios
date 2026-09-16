import Foundation
import KeeperCoreComponents
import TonAPI
import TonSwift

enum JettonTransferPayloadError: Swift.Error {
    case malformedHex
}

extension JettonTransferPayload {
    init(customPayload: String?, stateInit: String?) throws {
        if let customPayload {
            guard let data = Data(strictHex: customPayload) else {
                throw JettonTransferPayloadError.malformedHex
            }
            self.customPayload = try Cell.fromBoc(src: data)[0]
        } else {
            self.customPayload = nil
        }

        if let stateInit {
            guard let data = Data(strictHex: stateInit) else {
                throw JettonTransferPayloadError.malformedHex
            }
            self.stateInit = try Cell.fromBoc(src: data)[0]
        } else {
            self.stateInit = nil
        }
    }
}
