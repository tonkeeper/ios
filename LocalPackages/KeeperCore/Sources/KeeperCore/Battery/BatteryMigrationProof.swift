import Foundation
import TonSwift

public struct BatteryMigrationProof: Codable, Sendable {
    let signature: String

    public init?(destinationWallet: Wallet, keyPair: KeyPair) {
        guard let walletId = destinationWallet.multichainWalletState?.walletId,
              let message = Self.message(walletId: walletId, publicKey: keyPair.publicKey.data),
              let signature = try? WalletTransferSecretKeySigner(secretKey: keyPair.privateKey.data)
              .signMessage(message)
        else {
            return nil
        }
        self.signature = signature.hexString()
    }

    static func message(walletId: String, publicKey: Data) -> Data? {
        var message = Data()
        for part in [Data("keeper.battery.migrate.v1".utf8), Data(walletId.utf8), publicKey] {
            guard let length = UInt8(exactly: part.count) else {
                return nil
            }
            message.append(length)
            message.append(part)
        }
        return message
    }
}
