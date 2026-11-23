@testable import App
@testable import KeeperCore
import XCTest

final class MultichainSwapExactOutputSupportTests: XCTestCase {
    private let support = MultichainSwapExactOutputSupport(isEnabled: true)

    func test_tonPair_isSupportedWhenSwapsXyzListsBothAssets() {
        XCTAssertTrue(support.supports(
            sendAsset: asset("ton/mainnet/coin", aggregators: [.omniston, .swapsXyz, .swapKit]),
            receiveAsset: asset(Self.tonUsdt, aggregators: [.omniston, .swapsXyz])
        ))
    }

    func test_crossChainPair_isSupportedWhenSwapsXyzListsBothAssets() {
        XCTAssertTrue(support.supports(
            sendAsset: asset("ton/mainnet/coin", aggregators: [.omniston, .swapsXyz, .swapKit]),
            receiveAsset: asset("eth/mainnet/coin", aggregators: [.swapsXyz, .swapKit])
        ))
    }

    /// The swap never names Omniston, so an asset only Omniston lists is out of its reach.
    func test_omnistonOnlyAsset_isNotSupported() {
        XCTAssertFalse(support.supports(
            sendAsset: asset("ton/mainnet/coin", aggregators: [.omniston, .swapsXyz]),
            receiveAsset: asset(Self.tonUsdt, aggregators: [.omniston])
        ))
    }

    func test_swapKitOnlyAsset_isNotSupported() {
        XCTAssertFalse(support.supports(
            sendAsset: asset("sol/mainnet/coin", aggregators: [.swapsXyz, .swapKit]),
            receiveAsset: asset("sol/mainnet/spl/9gP2kCy3wA1ctvYWQk75guqXuHfrEomqydHLtcTCqiLa", aggregators: [.swapKit])
        ))
    }

    func test_assetWithoutAggregators_isNotSupported() {
        XCTAssertFalse(support.supports(
            sendAsset: asset("eth/mainnet/coin", aggregators: nil),
            receiveAsset: asset("ton/mainnet/coin", aggregators: [.omniston, .swapsXyz])
        ))
    }

    func test_disabledSupport_supportsNothing() {
        XCTAssertFalse(MultichainSwapExactOutputSupport(isEnabled: false).supports(
            sendAsset: asset("ton/mainnet/coin", aggregators: [.omniston, .swapsXyz]),
            receiveAsset: asset(Self.tonUsdt, aggregators: [.omniston, .swapsXyz])
        ))
    }
}

private extension MultichainSwapExactOutputSupportTests {
    static let tonUsdt = "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"

    func asset(_ assetId: String, aggregators: Set<MultichainSwapAggregator>?) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: assetId,
                symbol: assetId,
                decimals: 9,
                image: "",
                swapAggregators: aggregators
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
            balance: .zero
        )
    }
}
