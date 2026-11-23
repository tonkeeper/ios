@testable import App
@testable import KeeperCore
import XCTest

final class WalletConnectRequestFeeRowTests: XCTestCase {
    private let amountFormatter = WalletConnectRequestFeeRowTests.makeAmountFormatter()
    private let fee = WalletConnectEVMFee(amount: 3_000_000_000_000_000, limit: 21000, price: .gas(price: 3))

    func testLoadedFeeShowsItsFiatValueBelow() {
        let row = feeRow(.loaded(fee), feeAsset: asset(prices: ["USD": 2000]))

        XCTAssertEqual(row.subtitle, amountFormatter.format(decimal: 6, accessory: .fiat(Currency.USD), style: .compact))
    }

    func testFeeWithoutPriceInWalletCurrencyShowsNoFiat() {
        XCTAssertNil(feeRow(.loaded(fee), feeAsset: asset(prices: ["EUR": 1800])).subtitle)
        XCTAssertNil(feeRow(.loaded(fee), feeAsset: nil).subtitle)
    }

    func testUnpricedFeeShowsNoFiat() {
        let asset = asset(prices: ["USD": 2000])

        XCTAssertNil(feeRow(.loading, feeAsset: asset).subtitle)
        XCTAssertNil(feeRow(.unavailable, feeAsset: asset).subtitle)
    }
}

private extension WalletConnectRequestFeeRowTests {
    func feeRow(
        _ display: WalletConnectRequestFeeQuote.Display,
        feeAsset: MultichainAsset?
    ) -> WalletConnectRequestInfoRow {
        WalletConnectRequestAssembly.feeRow(
            display,
            chain: .arb,
            feeAsset: feeAsset,
            currency: .USD,
            amountFormatter: amountFormatter
        )
    }

    func asset(prices: [String: Double]) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: AssetId.coin(chain: .arb, network: .mainnet),
                name: "Ether",
                symbol: "ETH",
                decimals: 18,
                image: ""
            ),
            price: MultichainAssetPrice(prices: prices, diff24h: [:], diff7d: [:]),
            balance: .zero,
            marketCap: [:]
        )
    }

    static func makeAmountFormatter() -> AmountFormatter {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return AmountFormatter(configuration: configuration)
    }
}
