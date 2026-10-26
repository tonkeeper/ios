import Foundation

enum EarnHardcodedData {
    static let url = URL(string: "https://vaults-tonkeeper-earn-demo.fly.dev/")!

    static var featuredVaults: [EarnFeaturedVault] {
        rows.compactMap { EarnFeaturedVault(network: $0.network, vaultId: $0.vaultId) }
    }

    static var vaults: [EarnVault] {
        rows.map { row in
            EarnVault(
                network: row.network,
                vaultId: row.vaultId,
                assetSymbol: row.symbol,
                protocolName: row.protocolName,
                apy: row.apy,
                iconURL: nil
            )
        }
    }

    static var assetOffers: [EarnAssetOffer] {
        rows.compactMap { row in
            row.assetId.map { assetId in
                EarnAssetOffer(assetId: assetId, network: row.network, vaultId: row.vaultId, apy: row.apy)
            }
        }
    }

    static let positions: [EarnPosition] = [
        EarnPosition(
            network: "mainnet",
            vaultId: "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c",
            protocolName: "Aave",
            assetSymbol: "USDC",
            assetIconURL: nil,
            balanceUsd: 1.92,
            earnedUsd: 0.02
        ),
    ]

    private struct Row {
        let network: String
        let vaultId: String
        let symbol: String
        let protocolName: String
        let apy: Decimal
        let assetId: String?
    }

    private static let rows: [Row] = [
        Row(
            network: "mainnet",
            vaultId: "0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a",
            symbol: "USDT",
            protocolName: "Aave",
            apy: 2.58,
            assetId: "eth/mainnet/erc20/0xdAC17F958D2ee523a2206206994597C13D831ec7"
        ),
        Row(
            network: "mainnet",
            vaultId: "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c",
            symbol: "USDC",
            protocolName: "Aave",
            apy: 3.73,
            assetId: "eth/mainnet/erc20/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
        ),
        Row(network: "mainnet", vaultId: "0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8", symbol: "WETH", protocolName: "Aave", apy: 1.45, assetId: nil),
        Row(network: "base", vaultId: "0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca", symbol: "USDC", protocolName: "Moonwell", apy: 6.74, assetId: nil),
        Row(network: "arbitrum", vaultId: "0x724dc807b04555b71ed48a6896b6F41593b8C637", symbol: "USDC", protocolName: "Aave", apy: 3.73, assetId: nil),
        Row(network: "bsc", vaultId: "0xfD5840Cd36d94D7229439859C0112a4185BC0255", symbol: "USDT", protocolName: "Venus", apy: 3.56, assetId: nil),
    ]
}
