@testable import App
import BigInt
@testable import KeeperCore
import XCTest

final class AmountInputSwiftUIViewModelTests: XCTestCase {
    private struct StubUnit: AmountInputUnit {
        let inputSymbol: AmountInputSymbol
        let fractionalDigits: Int
        let symbol: String
    }

    func test_resetClearsInputTextAndDisablesContinue() {
        let viewModel = makeViewModel()
        viewModel.sourceBalance = BigUInt(1_000_000_000)
        viewModel.setText("0.5")
        XCTAssertEqual(viewModel.text, "0.5")
        XCTAssertTrue(viewModel.isEnable)

        viewModel.reset()

        XCTAssertEqual(viewModel.text, "")
        XCTAssertFalse(viewModel.isEnable)
    }

    func test_sourceUnitChangeClearsInputTextAndDisablesContinue() {
        let viewModel = makeViewModel()
        viewModel.sourceBalance = BigUInt(1_000_000_000)
        viewModel.setText("0.5")
        XCTAssertTrue(viewModel.isEnable)

        viewModel.sourceUnit = StubUnit(
            inputSymbol: .text("USDT"),
            fractionalDigits: 6,
            symbol: "USDT"
        )

        XCTAssertEqual(viewModel.text, "")
        XCTAssertFalse(viewModel.isEnable)
    }

    func test_backspaceDeletesTrailingSeparatorAndClearsField() {
        let viewModel = makeViewModel()
        viewModel.setText("0.5")
        XCTAssertEqual(viewModel.text, "0.5")

        viewModel.setText("0.")
        XCTAssertEqual(viewModel.text, "0.")

        viewModel.setText("0")
        XCTAssertEqual(viewModel.text, "0")

        viewModel.setText("")
        XCTAssertEqual(viewModel.text, "")
    }

    func test_typingLeadingZeroStillExpandsToFractionalShortcut() {
        let viewModel = makeViewModel()
        viewModel.setText("0")
        XCTAssertEqual(viewModel.text, "0.")
    }

    func test_convertedAmount_preservesSubCentCryptoOnFiatInput() throws {
        let viewModel = makeViewModel(
            sourceUnit: StubUnit(inputSymbol: .text("USD"), fractionalDigits: 2, symbol: "USD"),
            destinationUnit: StubUnit(inputSymbol: .text("BTC"), fractionalDigits: 8, symbol: "BTC")
        )
        // $100,000 / BTC → 0.00001 BTC per $1
        viewModel.rate = try NSDecimalNumber(decimal: XCTUnwrap(Decimal(string: "0.00001")))
        viewModel.setText("30")

        XCTAssertEqual(viewModel.converted.text, "0.0003")
        XCTAssertFalse(viewModel.converted.isHidden)
    }

    func test_convertedAmount_usdtNearParity() {
        let viewModel = makeViewModel(
            sourceUnit: StubUnit(inputSymbol: .text("USD"), fractionalDigits: 2, symbol: "USD"),
            destinationUnit: StubUnit(inputSymbol: .text("USDT"), fractionalDigits: 6, symbol: "USDT")
        )
        viewModel.rate = NSDecimalNumber(value: 1)
        viewModel.setText("30")

        XCTAssertEqual(viewModel.converted.text, "30")
    }

    private func makeViewModel(
        sourceUnit: StubUnit = StubUnit(
            inputSymbol: .text("TON"),
            fractionalDigits: 9,
            symbol: "TON"
        ),
        destinationUnit: StubUnit = StubUnit(
            inputSymbol: .text("USD"),
            fractionalDigits: 2,
            symbol: "USD"
        )
    ) -> AmountInputSwiftUIViewModel {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return AmountInputSwiftUIViewModel(
            amountFormatter: AmountFormatter(configuration: configuration),
            sourceUnit: sourceUnit,
            destinationUnit: destinationUnit
        )
    }
}
