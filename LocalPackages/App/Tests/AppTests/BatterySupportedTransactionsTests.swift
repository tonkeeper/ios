@testable import App
import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class BatterySupportedTransactionsTests: XCTestCase {
    func testALedgerHasTheBatteryForItsSwapsAndUSDTOnTron() {
        XCTAssertEqual(ledgerWallet(chains: [.tron, .eth]).supportedBatteryTransactions, [.swap, .trc20])
    }

    func testALedgerWithoutTronHasNothingTheBatteryPaysFor() {
        XCTAssertEqual(ledgerWallet(chains: [.eth, .sol]).supportedBatteryTransactions, [])
        XCTAssertEqual(ledgerWallet(chains: nil).supportedBatteryTransactions, [], "A TON-only Ledger")
    }

    func testAMultichainWalletWithTronHasTheBatteryForUSDTOnTron() {
        XCTAssertEqual(multichainWallet(chains: [.tron, .eth]).supportedBatteryTransactions, [.swap, .jetton, .nft, .trc20])
    }

    func testAMultichainWalletWithoutTronHasNoUSDTOnTron() {
        XCTAssertEqual(multichainWallet(chains: [.eth, .sol]).supportedBatteryTransactions, [.swap, .jetton, .nft])
    }

    func testAMultichainWalletListsTonThenTronThenItsRelayedEVMChains() {
        XCTAssertEqual(
            multichainWallet(chains: [.tron, .base]).batteryTransactionNetworks(relayedChains: [.base]),
            [
                BatteryTransactionNetwork(chain: .ton, transactions: [.swap, .jetton, .nft]),
                BatteryTransactionNetwork(chain: .tron, transactions: [.swap, .trc20]),
                BatteryTransactionNetwork(chain: .base, transactions: [.swap, .jetton]),
            ]
        )
    }

    func testALedgerListsTronAlone() {
        XCTAssertEqual(
            ledgerWallet(chains: [.tron, .eth]).batteryTransactionNetworks(relayedChains: []),
            [BatteryTransactionNetwork(chain: .tron, transactions: [.swap, .trc20])]
        )
        XCTAssertEqual(ledgerWallet(chains: nil).batteryTransactionNetworks(relayedChains: []), [])
    }

    private func ledgerWallet(chains: [MultichainChain]?) -> Wallet {
        let device = Wallet.LedgerDevice(deviceId: UUID().uuidString, deviceModel: "Ledger Stax", accountIndex: 0)
        return wallet(kind: .Ledger(publicKey, .v4R2, device), chains: chains)
    }

    private func multichainWallet(chains: [MultichainChain]) -> Wallet {
        wallet(kind: .Regular(publicKey, .v5R1), chains: chains)
    }

    private let publicKey = TonSwift.PublicKey(data: Data(repeating: 1, count: 32))

    private func wallet(kind: WalletKind, chains: [MultichainChain]?) -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: kind),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: chains.map { chains in
                .multichain(
                    MultichainWalletState(
                        walletId: "wallet",
                        addresses: chains.map { MultichainWalletAddress(chain: $0, address: "address-\($0.rawValue)") }
                    )
                )
            }
        )
    }
}
