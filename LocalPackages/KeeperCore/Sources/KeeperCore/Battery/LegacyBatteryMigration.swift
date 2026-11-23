import ChainKit
import Foundation
import KeeperCoreSensitive

struct LegacyBatteryMigration: Codable, Sendable {
    let id: String
    let destinationWalletId: String
    let proof: BatteryMigrationProof
    var requiresAuthorizationRefresh = false

    private enum CodingKeys: String, CodingKey {
        case id, destinationWalletId, proof, requiresAuthorizationRefresh
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        destinationWalletId = try container.decode(String.self, forKey: .destinationWalletId)
        proof = try container.decode(BatteryMigrationProof.self, forKey: .proof)
        requiresAuthorizationRefresh = try container.decodeIfPresent(Bool.self, forKey: .requiresAuthorizationRefresh) ?? false
    }

    init?(wallet: Wallet, mnemonic: CoreMnemonic) throws {
        guard wallet.network == .mainnet, wallet.kind == .regular, !wallet.isWalletTg,
              mnemonic.type == .bip39,
              let walletId = wallet.multichainWalletId
        else { return nil }
        let keyPair = try mnemonic.toKeyPair()
        let derived = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic.mnemonicWords.map { $0.lowercased() }.joined(separator: " "))
        guard derived.walletIdV2() == walletId,
              try keyPair.publicKey == (wallet.publicKey),
              let proof = BatteryMigrationProof(destinationWallet: wallet, keyPair: keyPair)
        else { throw BatteryAuthorizationError.unavailable }
        id = Self.identifier(wallet: wallet, walletId: walletId)
        destinationWalletId = walletId
        self.proof = proof
    }

    static func identifier(wallet: Wallet, walletId: String) -> String {
        "\(wallet.network.rawValue):\((try? wallet.publicKey.data.hexString()) ?? ""):" + walletId
    }

    func matches(_ wallet: Wallet) -> Bool {
        wallet.kind == .regular && !wallet.isWalletTg
            && wallet.multichainWalletId == destinationWalletId
            && Self.identifier(wallet: wallet, walletId: destinationWalletId) == id
    }

    static func sourceWallet(from wallet: Wallet) -> Wallet {
        Wallet(
            id: wallet.id,
            identity: wallet.identity,
            metaData: wallet.metaData,
            setupSettings: wallet.setupSettings,
            notificationSettings: wallet.notificationSettings,
            backupSettings: wallet.backupSettings,
            addressBook: wallet.addressBook,
            batterySettings: wallet.batterySettings,
            tron: wallet.tron,
            multichain: nil
        )
    }
}
