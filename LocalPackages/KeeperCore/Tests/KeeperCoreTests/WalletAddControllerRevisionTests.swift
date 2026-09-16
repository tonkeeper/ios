@testable import KeeperCore
import KeeperCoreSensitive
import TonSwift
import XCTest

final class WalletAddControllerRevisionTests: XCTestCase {
    func test_makeWalletRevision_preservesLegacyTronForBip39Wallet() throws {
        let mnemonic = bip39Mnemonic
        let tron = try XCTUnwrap(WalletTron(tonMnemonic: mnemonic.mnemonicWords))
        let sourceWallet = makeWallet(
            revision: .v4R2,
            tron: tron,
            multichain: .unavailable
        )
        let identity = WalletIdentity(
            network: .mainnet,
            kind: .Regular(publicKey, .v5R1)
        )

        let result = WalletAddController.makeWalletRevision(
            sourceWallet: sourceWallet,
            identity: identity,
            mnemonic: mnemonic
        )

        XCTAssertEqual(result.tron?.address.base58, tron.address.base58)
        XCTAssertEqual(result.multichain, .unavailable)
    }

    func test_makeWalletRevision_doesNotCopyMultichainStateBetweenTonRevisions() {
        let sourceWallet = makeWallet(
            revision: .v4R2,
            tron: nil,
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "multichain-wallet",
                    addresses: []
                )
            )
        )
        let identity = WalletIdentity(
            network: .mainnet,
            kind: .Regular(publicKey, .v5R1)
        )

        let result = WalletAddController.makeWalletRevision(
            sourceWallet: sourceWallet,
            identity: identity,
            mnemonic: bip39Mnemonic
        )

        XCTAssertNil(result.tron)
        XCTAssertNil(result.multichain)
    }
}

private extension WalletAddControllerRevisionTests {
    var bip39Mnemonic: CoreMnemonic {
        CoreMnemonic(
            mnemonicWords: Array(repeating: "abandon", count: 11) + ["about"],
            type: .bip39
        )
    }

    var publicKey: TonSwift.PublicKey {
        TonSwift.PublicKey(data: Data(repeating: 1, count: 32))
    }

    func makeWallet(
        revision: WalletContractVersion,
        tron: WalletTron?,
        multichain: MultichainWallet?
    ) -> Wallet {
        Wallet(
            id: UUID().uuidString,
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(publicKey, revision)
            ),
            metaData: WalletMetaData(
                label: "Wallet",
                tintColor: .SteelGray,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            tron: tron,
            multichain: multichain
        )
    }
}
