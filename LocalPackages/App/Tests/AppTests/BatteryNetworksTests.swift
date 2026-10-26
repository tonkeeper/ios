@testable import App
@testable import KeeperCore
import TonSwift
import XCTest

/// Which EVM chains the battery texts name for a wallet: only those its fees can be relayed on.
final class BatteryNetworksTests: XCTestCase {
    func test_aMultichainWalletGetsTheRelayedChainsItHasAnAddressOn() {
        let wallet = makeWallet(chains: [.ton, .eth, .base])

        let networks = BatteryNetworks(relayedEVMChains: [.eth, .base, .arb], wallet: wallet)

        XCTAssertEqual(networks.evmChains, [.eth, .base])
    }

    func test_aTonOnlyWalletGetsNoEVMChains() {
        let wallet = makeWallet(chains: nil)

        let networks = BatteryNetworks(relayedEVMChains: [.eth, .base], wallet: wallet)

        XCTAssertFalse(networks.includesEVM)
        XCTAssertNil(networks.caption)
    }

    func test_aTestnetWalletGetsNoEVMChains() {
        let wallet = makeWallet(chains: [.eth], network: .testnet)

        XCTAssertFalse(BatteryNetworks(relayedEVMChains: [.eth], wallet: wallet).includesEVM)
    }

    func test_aWalletThatSignsElsewhereGetsNoEVMChains() {
        let wallet = makeWallet(chains: [.eth], kind: .Signer(publicKey, .v4R2))

        XCTAssertFalse(BatteryNetworks(relayedEVMChains: [.eth], wallet: wallet).includesEVM)
    }
}

private extension BatteryNetworksTests {
    var publicKey: TonSwift.PublicKey {
        TonSwift.PublicKey(data: Data(repeating: 1, count: 32))
    }

    func makeWallet(
        chains: [MultichainChain]?,
        network: Network = .mainnet,
        kind: WalletKind? = nil
    ) -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(network: network, kind: kind ?? .Regular(publicKey, .v5R1)),
            metaData: WalletMetaData(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: chains.map { chains in
                .multichain(
                    MultichainWalletState(
                        walletId: "multichain-wallet",
                        addresses: chains.map { MultichainWalletAddress(chain: $0, address: "address-\($0.rawValue)") }
                    )
                )
            }
        )
    }
}
