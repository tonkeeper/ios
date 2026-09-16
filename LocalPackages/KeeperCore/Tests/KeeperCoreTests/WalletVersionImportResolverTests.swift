import Foundation
import KeeperCore
import KeeperCoreSensitive
import Testing
import TonSwift

struct WalletVersionImportResolverTests {
    @Test
    func importsW5WhenV4R2HasNoAssets() {
        let mnemonic = CoreMnemonic(mnemonicWords: Array(repeating: "word", count: 12), type: .bip39)
        let v4r2 = makeWallet(revision: .v4R2, tonBalance: 0)
        let w5 = makeWallet(revision: .v5R1, tonBalance: 1_000_000_000)

        let resolution = WalletVersionImportResolver.resolve(
            mnemonic: mnemonic,
            activeWallets: [v4r2, w5]
        )

        #expect(resolution == .importRevision(.currentVersion))
    }

    @Test
    func importsV4R2WhenOnlyV4R2HasAssets() {
        let mnemonic = CoreMnemonic(mnemonicWords: Array(repeating: "word", count: 12), type: .bip39)
        let v4r2 = makeWallet(revision: .v4R2, tonBalance: 1_000_000_000)
        let w5 = makeWallet(revision: .v5R1, tonBalance: 0)

        let resolution = WalletVersionImportResolver.resolve(
            mnemonic: mnemonic,
            activeWallets: [v4r2, w5]
        )

        #expect(resolution == .importRevision(.v4R2))
    }

    @Test
    func showsSelectionWhenBothVersionsHaveAssets() {
        let mnemonic = CoreMnemonic(mnemonicWords: Array(repeating: "word", count: 12), type: .bip39)
        let v4r2 = makeWallet(revision: .v4R2, tonBalance: 1_000_000_000)
        let w5 = makeWallet(revision: .v5R1, tonBalance: 2_000_000_000)

        let resolution = WalletVersionImportResolver.resolve(
            mnemonic: mnemonic,
            activeWallets: [v4r2, w5]
        )

        guard case let .showVersionSelection(selectedV4r2, selectedW5) = resolution else {
            Issue.record("Expected version selection")
            return
        }

        #expect(selectedV4r2.revision == .v4R2)
        #expect(selectedW5.revision == .v5R1)
    }

    @Test
    func usesExistingFlowForTonMnemonic() {
        let mnemonic = CoreMnemonic(mnemonicWords: Array(repeating: "word", count: 24), type: .ton)
        let wallets = [
            makeWallet(revision: .v4R2, tonBalance: 1),
            makeWallet(revision: .v5R1, tonBalance: 2),
        ]

        let resolution = WalletVersionImportResolver.resolve(
            mnemonic: mnemonic,
            activeWallets: wallets
        )

        guard case let .useExistingWalletSelection(selectedWallets) = resolution else {
            Issue.record("Expected existing wallet selection flow")
            return
        }

        #expect(selectedWallets.count == 2)
    }
}

private func makeWallet(
    revision: WalletContractVersion,
    tonBalance: Int64
) -> ActiveWalletModel {
    ActiveWalletModel(
        id: revision.rawValue,
        revision: revision,
        address: try! Address.parse(raw: "0:0000000000000000000000000000000000000000000000000000000000000000"),
        isActive: true,
        balance: Balance(
            tonBalance: TonBalance(amount: tonBalance),
            jettonsBalance: []
        ),
        nfts: [],
        history: .unknown
    )
}

extension WalletVersionImportResolver.Resolution: Equatable {
    public static func == (
        lhs: WalletVersionImportResolver.Resolution,
        rhs: WalletVersionImportResolver.Resolution
    ) -> Bool {
        switch (lhs, rhs) {
        case let (.importRevision(lRevision), .importRevision(rRevision)):
            return lRevision == rRevision
        case let (.showVersionSelection(lv4, lw5), .showVersionSelection(rv4, rw5)):
            return lv4.id == rv4.id && lw5.id == rw5.id
        case let (.useExistingWalletSelection(lwallets), .useExistingWalletSelection(rwallets)):
            return lwallets.map(\.id) == rwallets.map(\.id)
        default:
            return false
        }
    }
}
