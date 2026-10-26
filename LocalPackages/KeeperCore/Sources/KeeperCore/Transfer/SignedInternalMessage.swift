import Foundation
import TonSwift

enum SignedInternalMessage {
    static func boc(fromExternalBoc externalBoc: String, wallet: Wallet) throws -> String {
        let externalMessage = try Message.loadFrom(slice: Cell.fromBase64(src: externalBoc).beginParse())
        let internalMessage = try MessageRelaxed.internal(
            to: wallet.address,
            value: 0,
            bounce: false,
            stateInit: externalMessage.stateInit,
            body: externalMessage.body
        )
        return try Builder().store(internalMessage).endCell().toBoc().base64EncodedString()
    }
}
