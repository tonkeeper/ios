@testable import KeeperCore
import SwapAPI
import XCTest

final class MultichainSwapConfigTests: XCTestCase {
    func test_initMapsSwapPairAndSlippages() {
        let apiConfig = Components.Schemas.CrossSwapConfig(
            slippages: .init(
                additionalProperties: [
                    "base": .init(options_bps: [50, 100], default_bps: 100),
                    "eth": .init(options_bps: [100, 300], default_bps: 300),
                ]
            ),
            swap_pair: .init(
                source_asset_id: "base/mainnet/coin",
                destination_asset_id: "eth/mainnet/coin",
                source_asset: makeAPIAsset(
                    assetId: "base/mainnet/coin",
                    symbol: "BASE",
                    decimals: 18,
                    chainFamily: .EVM
                ),
                destination_asset: makeAPIAsset(
                    assetId: "eth/mainnet/coin",
                    symbol: "ETH",
                    decimals: 18,
                    chainFamily: .EVM
                )
            )
        )

        let config = MultichainSwapConfig(api: apiConfig)

        XCTAssertEqual(config.defaultPair.sourceAsset?.assetId, "base/mainnet/coin")
        XCTAssertEqual(config.defaultPair.sourceAsset?.symbol, "BASE")
        XCTAssertEqual(config.defaultPair.destinationAsset?.assetId, "eth/mainnet/coin")
        XCTAssertEqual(config.defaultPair.destinationAsset?.decimals, 18)
        XCTAssertEqual(
            config.slippage.chains,
            [
                "base": .init(optionsBps: [50, 100], defaultBps: 100),
                "eth": .init(optionsBps: [100, 300], defaultBps: 300),
            ]
        )
    }
}

private extension MultichainSwapConfigTests {
    func makeAPIAsset(
        assetId: String,
        symbol: String,
        decimals: Int,
        chainFamily: Components.Schemas.CrossSwapChainFamily
    ) -> Components.Schemas.CrossSwapAsset {
        Components.Schemas.CrossSwapAsset(
            asset_id: assetId,
            symbol: symbol,
            name: symbol,
            decimals: decimals,
            chain_family: chainFamily,
            supported_aggregators: []
        )
    }
}
