@testable import KeeperCore
import TonSwift
import XCTest

final class WalletConnectAccountResolverTests: XCTestCase {
    func test_accountsUseV4R2TONAddressForNonV5Wallets() throws {
        let versions: [WalletContractVersion] = [
            .v3R1,
            .v3R2,
            .v4R1,
            .v4R2,
            .v5Beta,
        ]

        for version in versions {
            let accounts = try WalletConnectAccountResolver().accounts(
                wallet: makeWallet(contractVersion: version),
                requiredChains: [.ton],
                optionalChains: []
            )

            XCTAssertEqual(
                accounts,
                [WalletConnectAccount(chain: .ton, address: "ton-v4r2")],
                "Unexpected TON account for \(version)"
            )
        }
    }

    func test_accountsUseV5R1TONAddressForV5Wallets() throws {
        let accounts = try WalletConnectAccountResolver().accounts(
            wallet: makeWallet(contractVersion: .v5R1),
            requiredChains: [.ton],
            optionalChains: []
        )

        XCTAssertEqual(
            accounts,
            [WalletConnectAccount(chain: .ton, address: "ton-v5r1")]
        )
    }
}

private extension WalletConnectAccountResolverTests {
    func makeWallet(contractVersion: WalletContractVersion) -> Wallet {
        Wallet(
            id: "wallet-\(contractVersion.rawValue)",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(
                    TonSwift.PublicKey(data: Data(repeating: 0x01, count: 32)),
                    contractVersion
                )
            ),
            metaData: WalletMetaData(
                label: "wallet",
                tintColor: .SteelGray,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "multichain-wallet",
                    addresses: [
                        MultichainWalletAddress(chain: .ton, address: "ton-v4r2", type: .tonV4R2),
                        MultichainWalletAddress(chain: .ton, address: "ton-v5r1", type: .tonV5R1),
                    ],
                    syncState: .synced
                )
            )
        )
    }
}
