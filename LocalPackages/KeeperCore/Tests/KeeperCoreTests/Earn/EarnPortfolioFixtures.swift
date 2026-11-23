import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import TonSwift

enum EarnPortfolioFixtures {
    static let multichainWalletId = "aiabcdefghijklmnopqrstuvwxyz2345672"

    static func wallet(
        id: String = "wallet",
        multichainWalletId: String? = multichainWalletId,
        syncState: MultichainWalletSyncState = .synced
    ) -> Wallet {
        Wallet(
            id: id,
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)
            ),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: multichainWalletId ?? "",
                    addresses: multichainWalletId == nil
                        ? []
                        : [MultichainWalletAddress(chain: .eth, address: "0x7ecebaf27c989adef9ea3dd06d316f6f463a5109")],
                    syncState: syncState
                )
            )
        )
    }

    static func portfolio(
        walletId: String = multichainWalletId,
        total: Decimal = Decimal(string: "0.2002")!
    ) -> EarnPortfolio {
        EarnPortfolio(
            walletId: walletId,
            totalFiat: ["USD": total],
            positions: [
                EarnPosition(
                    network: "mainnet",
                    vaultId: "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c",
                    protocolName: "Aave",
                    assetSymbol: "USDC",
                    assetIconURL: nil,
                    balanceFiat: ["USD": total],
                    earnedFiat: ["USD": Decimal(string: "0.000239")!]
                ),
            ]
        )
    }

    static func store(wallets: [Wallet], directory: URL) -> EarnPortfolioStore {
        EarnPortfolioStore(
            walletsStore: WalletsStore(
                keeperInfoStore: KeeperInfoStore(
                    keeperInfoRepository: EarnKeeperInfoRepositoryStub(wallets: wallets)
                )
            ),
            repository: EarnPortfolioRepository(
                fileSystemVault: FileSystemVault(fileManager: .default, directory: directory)
            )
        )
    }
}

private struct EarnKeeperInfoRepositoryStub: KeeperInfoRepository {
    let wallets: [Wallet]

    func getKeeperInfo() throws -> KeeperInfo {
        KeeperInfo(
            wallets: wallets,
            currentWallet: wallets[0],
            currency: .defaultCurrency,
            securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
            appSettings: KeeperInfo.AppSettings(
                isSecureMode: false,
                searchEngine: .duckduckgo,
                hidesDustBalances: false
            ),
            country: .auto
        )
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}
