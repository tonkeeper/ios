import BigInt
@testable import KeeperCore
import XCTest

final class MultichainSwapMaxAmountTests: XCTestCase {
    func test_tonNativeCoin_reservesOneTon() {
        let asset = makeAsset(assetId: "ton/mainnet/coin", decimals: 9, balance: 3_000_000_000)

        XCTAssertEqual(MultichainSwapMaxAmount.maxSwapInputAmount(for: asset), 2_000_000_000)
    }

    func test_tonNativeCoin_balanceBelowReserveGivesZero() {
        let asset = makeAsset(assetId: "ton/mainnet/coin", decimals: 9, balance: 500_000_000)

        XCTAssertEqual(MultichainSwapMaxAmount.maxSwapInputAmount(for: asset), 0)
    }

    func test_tonNativeCoin_balanceBelowReserveIsUnavailableForMax() {
        let asset = makeAsset(assetId: "ton/mainnet/coin", decimals: 9, balance: 500_000_000)

        XCTAssertTrue(MultichainSwapMaxAmount.tonMaxUnavailableDueToFeeReserve(for: asset))
    }

    func test_tonNativeCoin_balanceEqualToReserveIsUnavailableForMax() {
        let asset = makeAsset(assetId: "ton/mainnet/coin", decimals: 9, balance: 1_000_000_000)

        XCTAssertTrue(MultichainSwapMaxAmount.tonMaxUnavailableDueToFeeReserve(for: asset))
    }

    func test_tonNativeCoin_zeroBalanceIsNotUnavailableForMax() {
        let asset = makeAsset(assetId: "ton/mainnet/coin", decimals: 9, balance: 0)

        XCTAssertFalse(MultichainSwapMaxAmount.tonMaxUnavailableDueToFeeReserve(for: asset))
    }

    func test_tonNativeCoin_balanceAboveReserveIsAvailableForMax() {
        let asset = makeAsset(assetId: "ton/mainnet/coin", decimals: 9, balance: 3_000_000_000)

        XCTAssertFalse(MultichainSwapMaxAmount.tonMaxUnavailableDueToFeeReserve(for: asset))
    }

    func test_tonJetton_usesFullBalance() {
        let asset = makeAsset(assetId: "ton/mainnet/jetton/0:abc", decimals: 9, balance: 500_000_000)

        XCTAssertEqual(MultichainSwapMaxAmount.maxSwapInputAmount(for: asset), 500_000_000)
    }

    func test_otherNativeCoin_usesFullBalance() {
        let asset = makeAsset(assetId: "eth/mainnet/coin", decimals: 18, balance: 123)

        XCTAssertEqual(MultichainSwapMaxAmount.maxSwapInputAmount(for: asset), 123)
    }
}

private extension MultichainSwapMaxAmountTests {
    func makeAsset(assetId: String, decimals: Int, balance: BigUInt) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: "asset",
                symbol: "AST",
                decimals: decimals,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:], diff30d: [:]),
            balance: balance
        )
    }
}
