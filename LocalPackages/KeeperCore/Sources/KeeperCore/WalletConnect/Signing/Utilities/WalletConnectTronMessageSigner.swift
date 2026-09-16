import CryptoSwift
import Foundation
import TronSwift

enum WalletConnectTronMessageSigner {
    static func sign(
        message: String,
        privateKeyData: Data
    ) throws -> String {
        let prefix = "\u{19}TRON Signed Message:\n\(message.utf8.count)"
        var prefixedMessage = Data(prefix.utf8)
        prefixedMessage.append(contentsOf: message.utf8)

        let hash = prefixedMessage.sha3(.keccak256)
        let privateKey = TronSwift.PrivateKey(
            data: privateKeyData,
            chainCode: Data()
        )
        let signature = try Signer().sign(hash: hash, privateKey: privateKey)

        return "0x\(signature.hexString())"
    }
}
