@testable import App
import KeeperCore
import XCTest

final class PerpsDepositPriceTests: XCTestCase {
    @MainActor
    func testUSDCUsesOneDollarWithAMarketPriceOrWithoutOne() {
        for prices in [["USD": 0.9998], ["usd": 1.0002], [:]] {
            XCTAssertEqual(PerpsLiveDeposit.usdPrice(of: asset(symbol: "USDC", prices: prices)), 1)
        }
    }

    @MainActor
    func testOtherAssetsKeepTheirMarketPrice() {
        XCTAssertEqual(PerpsLiveDeposit.usdPrice(of: asset(symbol: "ETH", prices: ["USD": 2500])), 2500)
        XCTAssertEqual(PerpsLiveDeposit.usdPrice(of: asset(symbol: "USD₮", prices: ["usd": 0.99])), 0.99)
        XCTAssertNil(PerpsLiveDeposit.usdPrice(of: asset(symbol: "ETH", prices: [:])))
        XCTAssertNil(PerpsLiveDeposit.usdPrice(of: asset(symbol: "ETH", prices: ["USD": 0])))
    }

    private func asset(symbol: String, prices: [String: Double]) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: PerpsDepositService.targetAsset.assetId,
                name: symbol,
                symbol: symbol,
                decimals: 6,
                image: ""
            ),
            price: MultichainAssetPrice(prices: prices, diff24h: [:], diff7d: [:]),
            balance: .zero
        )
    }
}
