import Foundation
import TronSwift

public struct WalletTron: Codable {
    public let publicKey: TronSwift.PublicKey
    public let address: TronSwift.Address
}

extension WalletTron {
    init?(tonMnemonic: [String]) {
        guard let keyPair = try? TonTron.derivedKeyPair(
            tonMnemonic: tonMnemonic,
            index: 0
        ),
            let address = try? TronSwift.Address(publicKey: keyPair.publicKey)
        else {
            return nil
        }
        self.init(publicKey: keyPair.publicKey, address: address)
    }
}
