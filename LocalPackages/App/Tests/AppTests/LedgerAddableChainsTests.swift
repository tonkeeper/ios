@testable import App
import Foundation
@testable import KeeperCore
import TKFeatureFlags
import TonSwift
import XCTest

final class LedgerAddableChainsTests: XCTestCase {
    private let all = MultichainChain.displayOrder.filter(\.isEVM) + [.tron, .sol, .btc]

    func testATonOnlyLedgerOffersEveryNetworkOnceItsMigrationIsRolledOut() {
        let wallet = ledgerWallet(multichain: nil)

        XCTAssertEqual(wallet.addableLedgerChains(featureFlags: Flags([.ledgerMultichain])), [])
        XCTAssertEqual(wallet.addableLedgerChains(featureFlags: Flags([.ledgerMultichain, .ledgerMigration])), all)
        XCTAssertEqual(
            wallet.addableLedgerChains(featureFlags: Flags([.ledgerMigration])),
            [],
            "Without the multichain Ledger a Ledger has nothing to become"
        )
    }

    func testATestnetLedgerStaysTonOnly() {
        let wallet = ledgerWallet(multichain: nil, network: .testnet)

        XCTAssertEqual(wallet.addableLedgerChains(featureFlags: Flags([.ledgerMultichain, .ledgerMigration])), [])
    }

    func testAMultichainLedgerOffersOnlyWhatItLacks() {
        let state = MultichainWalletState(
            walletId: "ledger",
            addresses: all.filter(\.isEVM).map { MultichainWalletAddress(chain: $0, address: "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf") },
            syncState: .synced
        )
        let wallet = ledgerWallet(multichain: .multichain(state))

        XCTAssertEqual(wallet.addableLedgerChains(featureFlags: Flags([.ledgerMultichain])), [.tron, .sol, .btc])
        XCTAssertEqual(wallet.addableLedgerChains(featureFlags: Flags([])), [], "The multichain Ledger is not rolled out")
    }

    private func ledgerWallet(multichain: MultichainWallet?, network: Network = .mainnet) -> Wallet {
        let device = Wallet.LedgerDevice(deviceId: UUID().uuidString, deviceModel: "Ledger Stax", accountIndex: 0)
        return Wallet(
            id: "ledger",
            identity: WalletIdentity(network: network, kind: .Ledger(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2, device)),
            metaData: WalletMetaData(label: "Ledger", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }
}

private final class Flags: TKFeatureFlags {
    private let enabled: Set<FeatureFlag>

    init(_ enabled: Set<FeatureFlag>) {
        self.enabled = enabled
    }

    subscript(flag: FeatureFlag) -> Bool {
        get { enabled.contains(flag) }
        set {}
    }

    func devOverride(for _: FeatureFlag) -> Bool? {
        nil
    }

    func resetValue(for _: FeatureFlag) {}

    func loadRemoteConfig() async {}

    var allValues: [FeatureFlag: FeatureFlagValue] {
        [:]
    }
}
