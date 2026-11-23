import CryptoSwift
import Foundation
import WalletConnectSign

struct WalletConnectCryptoProvider: CryptoProvider {
    enum Error: Swift.Error {
        case unsupportedSignatureRecovery
    }

    func recoverPubKey(
        signature: EthereumSignature,
        message: Data
    ) throws -> Data {
        throw Error.unsupportedSignatureRecovery
    }

    func keccak256(_ data: Data) -> Data {
        data.sha3(.keccak256)
    }
}
