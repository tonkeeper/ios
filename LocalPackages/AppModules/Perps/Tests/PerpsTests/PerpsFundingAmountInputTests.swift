@testable import Perps
import PerpsModels
import TKTestSupport
import XCTest

final class PerpsFundingAmountInputTests: XCTestCase {
    func testLeadingDecimalSeparatorGetsAZero() {
        for text in [",3", ".3"] {
            var input = PerpsFundingAmountInput(tokenDecimals: 6, unit: .token)
            input.setText(text)
            XCTAssertEqual(input.text, "0.3")
            XCTAssertEqual(input.tokenAmount, Decimal(string: "0.3"))
        }
    }

    func testDollarEntryRoundsTokenAmountDown() {
        var input = PerpsFundingAmountInput(tokenDecimals: 6, unit: .usd, usdPrice: Decimal(string: "0.9998"))
        input.setText("10")

        // 10 / 0.9998 = 10.00200040008…; rounding up would ask for more than the dollars typed.
        XCTAssertEqual(input.tokenAmount, Decimal(string: "10.002"))
    }

    func testTokenEntryPricesDownToCents() {
        var input = PerpsFundingAmountInput(tokenDecimals: 6, unit: .token, usdPrice: Decimal(string: "0.9998"))
        input.setText("713.01")

        XCTAssertEqual(input.usdAmount, Decimal(string: "712.86"))
        XCTAssertEqual(input.tokenAmount, Decimal(string: "713.01"))
    }

    func testMaxInDollarsStaysWithinBalance() throws {
        var input = PerpsFundingAmountInput(tokenDecimals: 6, unit: .usd, usdPrice: Decimal(string: "0.9998"))
        let balance = try XCTUnwrap(Decimal(string: "3906.123456"))
        input.setMax(balance)

        XCTAssertEqual(input.text, "3905.34")
        XCTAssertLessThanOrEqual(try XCTUnwrap(input.tokenAmount), balance)
    }

    func testMaxInTokenKeepsTokenPrecision() throws {
        var input = PerpsFundingAmountInput(tokenDecimals: 6, unit: .token)
        try input.setMax(XCTUnwrap(Decimal(string: "3906.1234567")))

        XCTAssertEqual(input.text, "3906.123456")
    }

    func testMaxOfAnEighteenDecimalToken_showsNoMoreDigitsThanTyping() throws {
        var input = PerpsFundingAmountInput(tokenDecimals: 18, unit: .token, usdPrice: Decimal(string: "0.998"))
        try input.setMax(XCTUnwrap(Decimal(string: "21.133150354286632287")))
        XCTAssertEqual(input.text, "21.13315035")

        input.setMaxUsd(10)
        XCTAssertEqual(input.text, "10.02004008")

        input.toggleUnit()
        input.setText("10")
        input.toggleUnit()
        XCTAssertEqual(input.text, "10.02004008")
    }

    func testToggleCarriesEntryOver() {
        var input = PerpsFundingAmountInput(tokenDecimals: 6, unit: .token, usdPrice: 2)
        input.setText("1.5")

        input.toggleUnit()
        XCTAssertEqual(input.unit, .usd)
        XCTAssertEqual(input.text, "3")

        input.toggleUnit()
        XCTAssertEqual(input.unit, .token)
        XCTAssertEqual(input.text, "1.5")
    }

    func testTokenEntrySurvivesRepeatedToggles() {
        var input = PerpsFundingAmountInput(tokenDecimals: 9, unit: .token, usdPrice: Decimal(string: "4.99"))
        input.setText("0.3")

        for _ in 0 ..< 3 {
            input.toggleUnit()
            XCTAssertEqual(input.text, "1.49")
            input.toggleUnit()
            XCTAssertEqual(input.text, "0.3")
        }
        XCTAssertEqual(input.tokenAmount, Decimal(string: "0.3"))
    }

    func testDollarEntrySurvivesRepeatedToggles() {
        var input = PerpsFundingAmountInput(tokenDecimals: 9, unit: .usd, usdPrice: Decimal(string: "4.99"))
        input.setText("1.5")

        for _ in 0 ..< 3 {
            input.toggleUnit()
            XCTAssertEqual(input.text, "0.3006012")
            input.toggleUnit()
            XCTAssertEqual(input.text, "1.5")
        }
    }

    func testEditAfterToggleConvertsAfresh() {
        var input = PerpsFundingAmountInput(tokenDecimals: 9, unit: .token, usdPrice: Decimal(string: "4.99"))
        input.setText("0.3")
        input.toggleUnit()

        input.setText("2")
        input.toggleUnit()
        XCTAssertEqual(input.text, "0.4008016")
    }

    func testRetypingTheSameTextKeepsTheEntry() {
        var input = PerpsFundingAmountInput(tokenDecimals: 9, unit: .token, usdPrice: Decimal(string: "4.99"))
        input.setText("0.3")
        input.toggleUnit()

        input.setText("1.49")
        input.toggleUnit()
        XCTAssertEqual(input.text, "0.3")
    }

    func testMaxAfterToggleConvertsAfresh() throws {
        var input = PerpsFundingAmountInput(tokenDecimals: 9, unit: .token, usdPrice: Decimal(string: "4.99"))
        input.setText("0.3")
        input.toggleUnit()

        try input.setMax(XCTUnwrap(Decimal(string: "1")))
        XCTAssertEqual(input.text, "4.99")
        input.toggleUnit()
        XCTAssertEqual(input.text, "1")

        input.toggleUnit()
        input.setMaxUsd(2)
        input.toggleUnit()
        XCTAssertEqual(input.text, "0.4008016")
    }

    func testPriceUpdateConvertsAfresh() {
        var input = PerpsFundingAmountInput(tokenDecimals: 9, unit: .token, usdPrice: 5)
        input.setText("1")
        input.toggleUnit()
        input.toggleUnit()

        input.setUsdPrice(10)
        input.toggleUnit()
        XCTAssertEqual(input.text, "10")
        XCTAssertEqual(input.tokenAmount, 1)
    }

    func testSamePriceRefreshKeepsTheEntry() {
        var input = PerpsFundingAmountInput(tokenDecimals: 9, unit: .token, usdPrice: Decimal(string: "4.99"))
        input.setText("0.3")
        input.toggleUnit()

        input.setUsdPrice(Decimal(string: "4.99"))
        input.toggleUnit()
        XCTAssertEqual(input.text, "0.3")
    }

    func testLosingThePriceForgetsTheEntry() {
        var input = PerpsFundingAmountInput(tokenDecimals: 9, unit: .token, usdPrice: Decimal(string: "4.99"))
        input.setText("0.3")
        input.toggleUnit()

        input.setUsdPrice(nil)
        input.setUsdPrice(Decimal(string: "4.99"))
        input.toggleUnit()
        XCTAssertEqual(input.unit, .usd)
        XCTAssertEqual(input.text, "")
    }

    func testNoPriceKeepsTokenAndRefusesToggle() {
        var input = PerpsFundingAmountInput(tokenDecimals: 6, unit: .usd)
        input.setText("5")

        XCTAssertEqual(input.unit, .token)
        XCTAssertFalse(input.canToggleUnit)
        input.toggleUnit()
        XCTAssertEqual(input.unit, .token)
        XCTAssertNil(input.usdAmount)
    }

    func testLosingThePriceLeavesDollarEntry() {
        var input = PerpsFundingAmountInput(tokenDecimals: 6, unit: .usd, usdPrice: 1)
        input.setText("5")

        input.setUsdPrice(nil)

        // A dollar entry means nothing without a price; it must not be read as tokens.
        XCTAssertEqual(input.unit, .token)
        XCTAssertEqual(input.text, "")
    }

    func testEntryPrecisionFollowsUnit() {
        var input = PerpsFundingAmountInput(tokenDecimals: 6, unit: .usd, usdPrice: 1)
        input.setText("1.23456")
        XCTAssertEqual(input.text, "1.23")

        input.toggleUnit()
        input.setText("1.1234567")
        XCTAssertEqual(input.text, "1.123456")
    }
}

@MainActor
final class PerpsFundingAmountViewModelTests: XCTestCase {
    func testBalanceMaxAndReviewDoNotWaitForDestinationIcon() async {
        let icons = HeldLoads<URL?>()
        let viewModel = makeIconViewModel(icons)
        viewModel.onAppear()
        await icons.waitFor(1)
        await waitUntil(viewModel) { !viewModel.isBalanceLoading }
        XCTAssertFalse(viewModel.isBalanceLoading)
        XCTAssertTrue(viewModel.isMaxEnabled)
        XCTAssertEqual(viewModel.balance?.amount, "5")
        viewModel.setMax()
        XCTAssertEqual(viewModel.amountText, "5")
        XCTAssertTrue(viewModel.isReviewEnabled)
        XCTAssertNil(viewModel.asset.iconURL)
        let icon = URL(string: "https://example.com/usdc.png")
        icons.resolve(icon)
        await waitUntil(viewModel) { viewModel.asset.iconURL == icon }
        XCTAssertEqual(viewModel.asset.iconURL, icon)
        XCTAssertEqual(viewModel.balance?.amount, "5")
        XCTAssertEqual(viewModel.amountText, "5")
        viewModel.onDisappear()
    }

    func testLateIconFromPreviousDestinationCannotReplaceThePickedIcon() async {
        let icons = HeldLoads<URL?>()
        let viewModel = makeIconViewModel(icons)
        viewModel.onAppear()
        await icons.waitFor(1)
        let pickedIcon = URL(string: "https://example.com/picked.png")
        let firstLoad = viewModel.loadTask
        viewModel.assetDidChange(balance: .init(amount: "5", usdPrice: 1, iconURL: pickedIcon))
        await icons.waitFor(2)
        icons.resolve(URL(string: "https://example.com/old.png"))
        await awaitEnd(of: firstLoad)
        XCTAssertEqual(viewModel.asset.iconURL, pickedIcon)
        icons.resolve(nil)
        await awaitEnd(of: viewModel.loadTask)
        XCTAssertEqual(viewModel.asset.iconURL, pickedIcon)
        viewModel.onDisappear()
    }

    func testIconCompletionAfterDisappearanceDoesNotUpdateTheScreen() async {
        let icons = HeldLoads<URL?>()
        let viewModel = makeIconViewModel(icons)
        viewModel.onAppear()
        await icons.waitFor(1)
        let load = viewModel.loadTask
        viewModel.onDisappear()
        icons.resolve(URL(string: "https://example.com/usdc.png"))
        await load?.value
        XCTAssertNil(viewModel.asset.iconURL)
    }

    private func makeIconViewModel(_ icons: HeldLoads<URL?>) -> PerpsFundingAmountViewModel<Void> {
        PerpsFundingAmountViewModel(
            config: PerpsFundingAmountConfig(
                title: "", asset: { Self.usdc }, initialUnit: .usd, allowsUnitSwitching: false,
                fixedUsdPrice: 1, loadIcon: { await icons.next() },
                loadBalance: { .init(amount: "5", usdPrice: 1, iconURL: nil) },
                loadLimit: nil, requiresLimit: true, review: { _ in }, errorText: { _ in nil }
            ),
            format: .test
        )
    }

    func testLocalizedAmountSurvivesMaxEditingAndReview() async {
        var reviewedAmount: String?
        let viewModel = PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, network: .ethereum) },
                initialUnit: .usd,
                fixedUsdPrice: 1,
                loadBalance: { .init(amount: "4.289", usdPrice: 1, iconURL: nil) },
                loadLimit: nil,
                review: { reviewedAmount = $0 },
                errorText: { _ in nil }
            ),
            format: PerpsFormatting(amounts: PerpsTestAmountFormatting(), locale: Locale(identifier: "ru_RU"))
        )
        await load(viewModel)
        viewModel.setMax()
        XCTAssertEqual(viewModel.amountText, "4,28")
        viewModel.setAmount("0,0058")
        XCTAssertEqual(viewModel.amountText, "0,00")
        viewModel.toggleUnit()
        viewModel.setAmount("0,0058")
        XCTAssertEqual(viewModel.amountText, "0,0058")
        viewModel.review()
        await viewModel.reviewTask?.value
        XCTAssertEqual(reviewedAmount, "0.0058")
        XCTAssertEqual(viewModel.amountText, "0,0058")
        viewModel.onDisappear()
    }

    func testHugeTokenEntryKeepsEveryDigitInDollars() async {
        let viewModel = makeViewModel(balance: "2.16", limit: nil)
        await load(viewModel)

        viewModel.setAmount("555555555555555555555555555555")

        XCTAssertEqual(viewModel.counterpartText, "$555555555555555555555555555555")
    }

    func testUSDSwitcherHasALoadingPlaceholderAndIgnoresTaps() async {
        let balances = HeldLoads<PerpsFundingBalance?>()
        let viewModel = makeHeldBalanceViewModel(balances)

        XCTAssertEqual(viewModel.counterpartText, PerpsFormatting.test.usd(0))
        XCTAssertFalse(viewModel.canToggleUnit)
        viewModel.toggleUnit()
        XCTAssertEqual(viewModel.amountPrefix, "")

        viewModel.onAppear()
        await balances.waitFor(1)
        balances.resolve(.init(amount: "3", usdPrice: 1, iconURL: nil))
        await waitUntil(viewModel) { !viewModel.isBalanceLoading }

        XCTAssertTrue(viewModel.canToggleUnit)
        viewModel.toggleUnit()
        XCTAssertEqual(viewModel.amountPrefix, "$")
    }

    func testAvailableIsHiddenWhileBalanceLoadsAndShowsKnownZero() async {
        let balances = HeldLoads<PerpsFundingBalance?>()
        let viewModel = makeHeldBalanceViewModel(balances)

        XCTAssertTrue(viewModel.isBalanceLoading)
        XCTAssertNil(viewModel.availableText)
        XCTAssertFalse(viewModel.isAssetLoading)
        XCTAssertEqual(viewModel.amountSuffix, "USDC")
        XCTAssertEqual(viewModel.asset.network, .ethereum)
        viewModel.onAppear()
        await balances.waitFor(1)
        XCTAssertTrue(viewModel.isBalanceLoading)

        balances.resolve(.init(amount: "0", usdPrice: 1, iconURL: nil))
        await waitUntil(viewModel) { !viewModel.isBalanceLoading }

        XCTAssertFalse(viewModel.isBalanceLoading)
        XCTAssertEqual(viewModel.availableText, PerpsFormatting.test.tokenCompact(0, symbol: "USDC"))
        XCTAssertFalse(viewModel.isMaxEnabled)
    }

    func testAvailableDoesNotWaitForTheMaxFeeReserve() async {
        let limits = HeldLoads<String?>()
        let viewModel = makeHeldLimitViewModel(limits)
        viewModel.onAppear()
        await limits.waitFor(1)
        await waitUntil(viewModel) { viewModel.balance != nil }

        XCTAssertFalse(viewModel.isBalanceLoading)
        XCTAssertEqual(viewModel.availableText, PerpsFormatting.test.tokenCompact(1, symbol: "ETH"))
        XCTAssertNil(viewModel.limit)

        limits.resolve("0.99")
        await waitUntil(viewModel) { viewModel.limit != nil }
        XCTAssertEqual(viewModel.limit, Decimal(string: "0.99"))
    }

    func testUnknownBalanceStopsShimmerWithoutWaitingForTheMaxFeeReserve() async {
        let limits = HeldLoads<String?>()
        let viewModel = makeHeldLimitViewModel(limits, balance: nil)
        viewModel.onAppear()
        await limits.waitFor(1)
        await waitUntil(viewModel) { !viewModel.isBalanceLoading }

        XCTAssertFalse(viewModel.isBalanceLoading)
        XCTAssertNil(viewModel.availableText)
        XCTAssertFalse(viewModel.isMaxEnabled)
        limits.resolve(nil)
    }

    func testOldBalanceLoadCannotStopNewLoadingState() async {
        let balances = HeldLoads<PerpsFundingBalance?>()
        let viewModel = makeHeldBalanceViewModel(balances)
        viewModel.onAppear()
        await balances.waitFor(1)

        let firstLoad = viewModel.loadTask
        viewModel.assetDidChange(balance: nil)
        await balances.waitFor(2)
        balances.resolve(.init(amount: "10", usdPrice: 1, iconURL: nil))
        await firstLoad?.value
        XCTAssertTrue(viewModel.isBalanceLoading)
        XCTAssertNil(viewModel.availableText)

        balances.resolve(.init(amount: "2", usdPrice: 1, iconURL: nil))
        await waitUntil(viewModel) { !viewModel.isBalanceLoading }
        XCTAssertFalse(viewModel.isBalanceLoading)
        XCTAssertEqual(viewModel.availableText, PerpsFormatting.test.tokenCompact(2, symbol: "USDC"))
    }

    func testWithdrawalCannotReviewWhenTheDestinationBalanceIsUnavailable() async {
        let viewModel = PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "lighter/mainnet/usdc", symbol: "USDC", decimals: 6, network: .ethereum) },
                initialUnit: .usd,
                fixedUsdPrice: 1,
                loadBalance: { nil },
                loadLimit: nil,
                requiresLimit: true,
                review: { _ in XCTFail("an unavailable destination must not be reviewed") },
                errorText: { _ in nil }
            ),
            format: .test
        )
        viewModel.setAmount("1")
        XCTAssertFalse(viewModel.isReviewEnabled)
        await load(viewModel)
        XCTAssertFalse(viewModel.isReviewEnabled)
        viewModel.review()
    }

    func testWithdrawalDisplaysDestinationIconWhileAmountStaysInUSD() async throws {
        let iconURL = try XCTUnwrap(URL(string: "https://example.com/btc.png"))
        let viewModel = PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "lighter/mainnet/usdc", symbol: "USDC", decimals: 6, network: .ethereum) },
                displayAsset: { balance, _ in
                    .init(assetId: "btc/mainnet/coin", symbol: "BTC", network: .bitcoin, iconURL: balance?.iconURL, balanceText: nil)
                },
                initialUnit: .usd,
                allowsUnitSwitching: false,
                fixedUsdPrice: 1,
                loadBalance: { .init(amount: "10", usdPrice: 1, iconURL: iconURL) },
                loadLimit: nil,
                review: { _ in },
                errorText: { _ in nil }
            ),
            format: .test
        )
        XCTAssertNil(viewModel.asset.iconURL)

        await load(viewModel)
        viewModel.setAmount("2")
        viewModel.toggleUnit()

        XCTAssertEqual(viewModel.asset.iconURL, iconURL)
        XCTAssertEqual(viewModel.asset.symbol, "BTC")
        XCTAssertEqual(viewModel.asset.network, .bitcoin)
        XCTAssertNil(viewModel.asset.balanceText)
        XCTAssertEqual(viewModel.amountPrefix, "$")
        XCTAssertNil(viewModel.amountSuffix)
        XCTAssertNil(viewModel.counterpartText)
        XCTAssertFalse(viewModel.canToggleUnit)
        XCTAssertEqual(viewModel.amountText, "2")
    }

    func testWithdrawalTogglesIntoTheDestinationTokenAndStillReviewsDollars() async throws {
        var reviewed: String?
        let viewModel = makeWithdrawViewModel { reviewed = $0 }
        await load(viewModel)

        XCTAssertTrue(viewModel.canToggleUnit)
        viewModel.setAmount("100")
        XCTAssertEqual(viewModel.counterpartText, try PerpsFormatting.test.tokenCompact(XCTUnwrap(Decimal(string: "0.002")), symbol: "BTC"))

        viewModel.toggleUnit()
        XCTAssertEqual(viewModel.amountSuffix, "BTC")
        XCTAssertEqual(viewModel.amountText, PerpsFormatting.test.input("0.002"))
        XCTAssertEqual(viewModel.counterpartText, PerpsFormatting.test.usd(100))

        let done = expectation(description: "reviewed")
        viewModel.onReviewed = { _ in done.fulfill() }
        viewModel.review()
        await fulfillment(of: [done], timeout: 1)
        XCTAssertEqual(reviewed, "100")
    }

    func testWithdrawalLimitsAndMaxStayInDollarsWhileTypedInTheToken() async throws {
        var reviewed: String?
        let viewModel = makeWithdrawViewModel { reviewed = $0 }
        await load(viewModel)
        viewModel.toggleUnit()

        viewModel.setAmount("0.03")
        XCTAssertFalse(viewModel.isReviewEnabled, "0.03 BTC is $1500, over the $1000 balance")
        XCTAssertEqual(viewModel.availableText, try PerpsFormatting.test.tokenCompact(XCTUnwrap(Decimal(string: "0.02")), symbol: "BTC"))

        viewModel.setMax()
        XCTAssertEqual(viewModel.amountText, PerpsFormatting.test.input("0.02"))
        XCTAssertTrue(viewModel.isReviewEnabled)
        let done = expectation(description: "reviewed")
        viewModel.onReviewed = { _ in done.fulfill() }
        viewModel.review()
        await fulfillment(of: [done], timeout: 1)
        XCTAssertEqual(reviewed, "1000")
    }

    func testWithdrawalWithoutADestinationPriceStaysInDollars() async {
        let viewModel = makeWithdrawViewModel(destinationPrice: nil) { _ in }
        await load(viewModel)

        XCTAssertFalse(viewModel.canToggleUnit)
        XCTAssertNil(viewModel.counterpartText)
        viewModel.setAmount("100")
        XCTAssertEqual(viewModel.amountPrefix, "$")
        XCTAssertTrue(viewModel.isReviewEnabled)
    }

    func testPickingAnotherDestinationKeepsTheDollarsAndRepricesThem() async {
        let viewModel = makeWithdrawViewModel { _ in }
        await load(viewModel)
        viewModel.setAmount("100")

        let ton = PerpsDepositSourceOption(
            source: .init(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, network: .ton),
            balance: .init(amount: "3", usdPrice: 2, iconURL: nil)
        )
        viewModel.assetDidChange(balance: viewModel.balance, destination: ton)

        XCTAssertEqual(viewModel.amountText, "100")
        XCTAssertEqual(viewModel.counterpartText, PerpsFormatting.test.tokenCompact(50, symbol: "TON"))
    }

    func testPickingAnUnpricedDestinationAfterATokenEntryFallsBackToDollars() async {
        let viewModel = makeWithdrawViewModel { _ in }
        await load(viewModel)
        viewModel.toggleUnit()
        viewModel.setAmount("0.001")

        let unpriced = PerpsDepositSourceOption(
            source: .init(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, network: .ton),
            balance: .init(amount: "3", usdPrice: nil, iconURL: nil)
        )
        viewModel.assetDidChange(balance: viewModel.balance, destination: unpriced)

        XCTAssertEqual(viewModel.amountPrefix, "$")
        XCTAssertFalse(viewModel.isReviewEnabled)
    }

    func testReviewRefusedOverLimitAndSaysWhy() async {
        let viewModel = makeViewModel(balance: "10", limit: nil)
        await load(viewModel)

        viewModel.setAmount("10.01")

        XCTAssertFalse(viewModel.isReviewEnabled)
        XCTAssertNotNil(viewModel.warningText)
    }

    func testReviewStaysOffBelowTheSourceMinimumAndNamesIt() async {
        let viewModel = PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "tron/mainnet/coin", symbol: "TRX", decimals: 6, network: .tron) },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { .init(amount: "100", usdPrice: 0.3, iconURL: nil) },
                loadLimit: nil,
                loadMinimum: { PerpsFundingMinimum(amount: 3.5, text: "minimum") },
                review: { _ in },
                errorText: { _ in nil }
            ),
            format: .test
        )
        viewModel.setAmount("3.49")
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.warningText != nil }

        XCTAssertEqual(viewModel.warningText, "minimum")
        XCTAssertFalse(viewModel.isReviewEnabled)

        viewModel.setAmount("3.5")
        XCTAssertNil(viewModel.warningText)
        XCTAssertTrue(viewModel.isReviewEnabled)

        viewModel.setAmount("")
        XCTAssertNil(viewModel.warningText)
    }

    func testHiddenBalancesMaskAvailableAndTheAssetBalance() async {
        let viewModel = makeViewModel(
            balance: "10",
            limit: nil,
            format: PerpsFormatting(amounts: PerpsTestAmountFormatting()) { "* * *" }
        )
        await load(viewModel)

        XCTAssertEqual(viewModel.availableText, "* * *")
        XCTAssertEqual(viewModel.asset.balanceText, "* * *")
    }

    func testLimitOverridesWalletBalance() async {
        let viewModel = makeViewModel(balance: "3906", limit: "712.56")
        await load(viewModel)

        viewModel.setMax()

        XCTAssertEqual(viewModel.amountText, "712.56")
        XCTAssertTrue(viewModel.isReviewEnabled)

        viewModel.setAmount("712.57")
        XCTAssertFalse(viewModel.isReviewEnabled)
        XCTAssertNotNil(viewModel.warningText)
    }

    func testEthDepositQuotesEnteredDollarsInsteadOfRejectingAgainstMaxReserve() async {
        var quotedAmount: String?
        let viewModel = makeEthDepositViewModel(maximum: "0.00025") { amount in
            quotedAmount = amount
        }
        await load(viewModel)
        viewModel.toggleUnit()

        for dollars in ["1", "2"] {
            viewModel.setAmount(dollars)
            XCTAssertTrue(viewModel.isReviewEnabled)
            XCTAssertNil(viewModel.warningText)
        }
        XCTAssertEqual(viewModel.availableText, PerpsFormatting.test.usd(2.5))

        let quoted = expectation(description: "entered amount quoted")
        viewModel.onReviewed = { _ in quoted.fulfill() }
        viewModel.review()
        await fulfillment(of: [quoted], timeout: 1)
        XCTAssertEqual(quotedAmount, "0.001")
    }

    func testEthDepositMaxKeepsFeeReserveButValidationUsesWalletBalance() async {
        let viewModel = makeEthDepositViewModel(maximum: "0.00025") { _ in }
        await load(viewModel)
        viewModel.toggleUnit()
        viewModel.setMax()

        XCTAssertEqual(viewModel.amountText, "0.5")
        XCTAssertTrue(viewModel.isReviewEnabled)

        viewModel.setAmount("2.51")
        XCTAssertFalse(viewModel.isReviewEnabled)
        XCTAssertNotNil(viewModel.warningText)
    }

    func testZeroEstimatedMaxDoesNotPreventQuotingSmallerDeposit() async {
        let viewModel = makeEthDepositViewModel(maximum: "0") { _ in }
        await load(viewModel)
        viewModel.toggleUnit()
        viewModel.setAmount("1")

        XCTAssertFalse(viewModel.isMaxEnabled)
        XCTAssertTrue(viewModel.isReviewEnabled)
        XCTAssertNil(viewModel.warningText)
    }

    func testUnknownBalanceDoesNotBlockReview() async {
        let viewModel = makeViewModel(balance: nil, limit: nil)
        await load(viewModel)

        viewModel.setAmount("5")

        XCTAssertTrue(viewModel.isReviewEnabled)
        XCTAssertFalse(viewModel.isMaxEnabled)
        XCTAssertNil(viewModel.availableText)
        XCTAssertFalse(viewModel.isBalanceLoading)
    }

    func testReviewSendsTokenAmountFromDollarEntry() async {
        var reviewed: String?
        let viewModel = PerpsFundingAmountViewModel<String>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum) },
                initialUnit: .usd,
                fixedUsdPrice: Decimal(string: "0.5"),
                loadBalance: { nil },
                loadLimit: { nil },
                review: { amount in
                    reviewed = amount
                    return amount
                },
                errorText: { _ in nil }
            ),
            format: .test
        )
        let done = expectation(description: "reviewed")
        viewModel.onReviewed = { _ in done.fulfill() }
        viewModel.setAmount("3")
        viewModel.review()
        await fulfillment(of: [done], timeout: 1)

        XCTAssertEqual(reviewed, "6")
    }

    func testPendingPaymentCanBeReviewedWithNoBalanceOrAmount() async {
        let viewModel = PerpsFundingAmountViewModel<String>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum) },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { .init(amount: "0", usdPrice: 1, iconURL: nil) },
                loadLimit: nil,
                review: { _ in XCTFail("a fresh quote must not be requested"); return "fresh" },
                errorText: { _ in nil }
            ),
            format: .test,
            loadPendingReview: { "pending" },
            pendingNotice: "Finish the pending payment"
        )
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.isReviewEnabled }

        XCTAssertTrue(viewModel.isReviewEnabled)
        XCTAssertEqual(viewModel.warningText, "Finish the pending payment")
        var reviewed: String?
        viewModel.onReviewed = { reviewed = $0 }
        viewModel.review()
        XCTAssertEqual(reviewed, "pending")
    }

    func testAPendingPaymentShowsTheAssetItWasPaidWith() async {
        var source = PerpsDepositSource(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum)
        let viewModel = PerpsFundingAmountViewModel<String>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { source },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { nil },
                loadLimit: nil,
                review: { _ in "fresh" },
                errorText: { _ in nil }
            ),
            format: .test,
            loadPendingReview: {
                source = PerpsDepositSource(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, network: .ton)
                return "pending"
            },
            pendingNotice: "Finish the pending payment"
        )
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.warningText != nil }

        XCTAssertEqual(viewModel.asset.assetId, "ton/mainnet/coin")
        XCTAssertEqual(viewModel.amountSuffix, "TON")
        viewModel.setAmount("1.1234567")
        XCTAssertEqual(viewModel.amountText, "1.1234567")
    }

    func testReviewCompletionAfterLeavingTheFormIsIgnored() async {
        var release: CheckedContinuation<Void, Never>?
        let started = expectation(description: "review started")
        var didReview = false
        let viewModel = PerpsFundingAmountViewModel<String>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum) },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { nil },
                loadLimit: nil,
                review: { _ in
                    await withCheckedContinuation { continuation in
                        release = continuation
                        started.fulfill()
                    }
                    return "late"
                },
                errorText: { _ in nil }
            ),
            format: .test
        )
        viewModel.onReviewed = { _ in didReview = true }
        viewModel.setAmount("1")
        viewModel.review()
        await fulfillment(of: [started], timeout: 5)
        let review = viewModel.reviewTask

        viewModel.onDisappear()
        release?.resume()
        await review?.value
        XCTAssertFalse(didReview)
        XCTAssertFalse(viewModel.isReviewInFlight)
    }

    func testAssetSwitchDropsTheOldReviewCompletion() async {
        await checkAssetSwitchDropsOldReview(.success("old"))
    }

    func testAssetSwitchDropsTheOldReviewError() async {
        await checkAssetSwitchDropsOldReview(.failure(.failed))
    }

    private enum ReviewError: Error {
        case failed
    }

    private func checkAssetSwitchDropsOldReview(_ oldResult: Result<String, ReviewError>) async {
        let reviews = HeldLoads<Result<String, ReviewError>>()
        let oldReturned = expectation(description: "old review returned")
        let newReviewed = expectation(description: "new asset reviewed")
        var source = PerpsDepositSource(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum)
        let viewModel = PerpsFundingAmountViewModel<String>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { source },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { nil },
                loadLimit: nil,
                review: { _ in
                    let result = await reviews.next()
                    if Task.isCancelled { oldReturned.fulfill() }
                    return try result.get()
                },
                errorText: { _ in "old error" }
            ),
            format: .test
        )
        var reviewed = [String]()
        viewModel.onReviewed = {
            reviewed.append($0)
            if $0 == "new" { newReviewed.fulfill() }
        }
        viewModel.setAmount("1")
        viewModel.review()
        await reviews.waitFor(1)
        XCTAssertTrue(viewModel.isReviewInFlight)

        source = PerpsDepositSource(assetId: "btc/mainnet/coin", symbol: "BTC", decimals: 8, network: .bitcoin)
        viewModel.assetDidChange(balance: nil)
        XCTAssertFalse(viewModel.isReviewInFlight)
        viewModel.setAmount("0.1")
        viewModel.review()
        await reviews.waitFor(2)

        reviews.resolve(oldResult)
        await fulfillment(of: [oldReturned], timeout: 1)
        XCTAssertTrue(viewModel.isReviewInFlight)
        XCTAssertNil(viewModel.errorText)
        XCTAssertTrue(reviewed.isEmpty)
        XCTAssertEqual(viewModel.amountSuffix, "BTC")
        XCTAssertEqual(viewModel.amountText, "0.1")

        reviews.resolve(.success("new"))
        await fulfillment(of: [newReviewed], timeout: 1)
        XCTAssertEqual(reviewed, ["new"])
        XCTAssertFalse(viewModel.isReviewInFlight)
    }

    func testAssetSwitchShowsThePickersBalanceAndDropsTheOldAssetsLoad() async {
        let loads = HeldLoads<PerpsFundingBalance?>()
        var source = PerpsDepositSource(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum)
        let viewModel = PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { source },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { await loads.next() },
                loadLimit: nil,
                review: { _ in },
                errorText: { _ in nil }
            ),
            format: .test
        )
        viewModel.onAppear()
        viewModel.setAmount("5")
        await loads.waitFor(1)

        source = PerpsDepositSource(assetId: "btc/mainnet/coin", symbol: "BTC", decimals: 8, network: .bitcoin)
        let listed = PerpsFundingBalance(amount: "0.5", usdPrice: 60000, iconURL: URL(string: "https://example.com/btc.png"))
        let firstLoad = viewModel.loadTask
        viewModel.assetDidChange(balance: listed)

        XCTAssertEqual(viewModel.asset.iconURL, listed.iconURL)
        XCTAssertNotNil(viewModel.availableText)
        XCTAssertFalse(viewModel.isBalanceLoading)
        XCTAssertEqual(viewModel.amountSuffix, "BTC")
        XCTAssertEqual(viewModel.amountText, "")

        await loads.waitFor(2)
        loads.resolve(.init(amount: "10", usdPrice: 1, iconURL: nil))
        await firstLoad?.value
        XCTAssertEqual(viewModel.balance, listed)

        let loaded = PerpsFundingBalance(amount: "0.6", usdPrice: 60000, iconURL: listed.iconURL)
        loads.resolve(loaded)
        await waitUntil(viewModel) { viewModel.balance == loaded }
        XCTAssertEqual(viewModel.balance, loaded)
    }

    func testMaxTappedWhileTheLimitIsPricedLandsWithIt() async {
        let limits = HeldLoads<String?>()
        let viewModel = makeHeldLimitViewModel(limits)
        viewModel.assetDidChange(balance: .init(amount: "1", usdPrice: 2000, iconURL: nil))
        await limits.waitFor(1)

        XCTAssertTrue(viewModel.isMaxEnabled)
        viewModel.setMax()
        XCTAssertTrue(viewModel.isMaxPending)
        XCTAssertEqual(viewModel.amountText, "")

        limits.resolve("0.99")
        await waitUntil(viewModel) { !viewModel.isMaxPending }
        XCTAssertFalse(viewModel.isMaxPending)
        XCTAssertEqual(viewModel.amountText, "0.99")
    }

    func testTypingCancelsAPendingMax() async {
        let limits = HeldLoads<String?>()
        let viewModel = makeHeldLimitViewModel(limits)
        viewModel.assetDidChange(balance: .init(amount: "1", usdPrice: 2000, iconURL: nil))
        await limits.waitFor(1)
        viewModel.setMax()
        viewModel.setAmount("0.1")
        XCTAssertFalse(viewModel.isMaxPending)

        limits.resolve("0.99")
        await waitUntil(viewModel) { viewModel.limit != nil }
        XCTAssertEqual(viewModel.amountText, "0.1")
    }

    func testDepositStartsFromTheLargestHoldingOnceListed() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, source) = makePreferringViewModel(preferred)
        XCTAssertTrue(viewModel.isAssetLoading)
        XCTAssertNil(viewModel.amountSuffix)
        XCTAssertEqual(viewModel.counterpartText, PerpsFormatting.test.usd(0))
        viewModel.onAppear()
        await preferred.waitFor(1)
        await waitUntil(viewModel) { viewModel.balance != nil }
        XCTAssertNotNil(viewModel.balance)
        XCTAssertTrue(viewModel.isBalanceLoading)
        XCTAssertNil(viewModel.amountSuffix)
        XCTAssertNil(viewModel.availableText)
        XCTAssertFalse(viewModel.canToggleUnit)

        preferred.resolve(Self.tonOption)
        await waitUntil(viewModel) { viewModel.amountSuffix == "TON" }
        XCTAssertEqual(source.value.assetId, "ton/mainnet/coin")
        XCTAssertFalse(viewModel.isAssetLoading)
        XCTAssertEqual(viewModel.asset.network, .ton)
        XCTAssertEqual(viewModel.asset.iconURL, Self.tonOption.balance?.iconURL)
        XCTAssertEqual(viewModel.balance, Self.tonOption.balance)

        await awaitEnd(of: viewModel.loadTask)
        XCTAssertEqual(preferred.waitingCount, 0)
    }

    func testNoPreferredHoldingRevealsTheDefaultAsset() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, source) = makePreferringViewModel(preferred)
        viewModel.onAppear()
        await preferred.waitFor(1)
        XCTAssertTrue(viewModel.isAssetLoading)

        preferred.resolve(nil)
        await waitUntil(viewModel) { !viewModel.isAssetLoading }

        XCTAssertFalse(viewModel.isAssetLoading)
        XCTAssertFalse(viewModel.isBalanceLoading)
        XCTAssertEqual(source.value.assetId, Self.usdc.assetId)
        XCTAssertEqual(viewModel.amountSuffix, "USDC")
        XCTAssertNotNil(viewModel.availableText)
    }

    func testDepositKeepsItsAssetOnceTheUserHasStartedTyping() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, source) = makePreferringViewModel(preferred)
        viewModel.onAppear()
        await preferred.waitFor(1)
        viewModel.setAmount("5")
        XCTAssertFalse(viewModel.isAssetLoading)

        preferred.resolve(Self.tonOption)
        await awaitEnd(of: viewModel.loadTask)

        XCTAssertEqual(source.value.assetId, Self.usdc.assetId)
        XCTAssertEqual(viewModel.amountText, "5")
        XCTAssertEqual(viewModel.amountSuffix, "USDC")
    }

    func testClearingTheTypedAmountKeepsTheAssetShown() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, source) = makePreferringViewModel(preferred)
        viewModel.onAppear()
        await preferred.waitFor(1)
        viewModel.setAmount("5")
        viewModel.setAmount("")
        XCTAssertFalse(viewModel.isAssetLoading)
        XCTAssertEqual(viewModel.amountSuffix, "USDC")

        preferred.resolve(Self.tonOption)
        await awaitEnd(of: viewModel.loadTask)

        XCTAssertEqual(source.value.assetId, Self.usdc.assetId)
        XCTAssertFalse(viewModel.isAssetLoading)
    }

    func testAnAssetPickedWhileTheHoldingsLoadIsNotReplaced() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, source) = makePreferringViewModel(preferred)
        viewModel.onAppear()
        await preferred.waitFor(1)

        let holdingsLoad = viewModel.loadTask
        source.value = PerpsDepositSource(assetId: "btc/mainnet/coin", symbol: "BTC", decimals: 8, network: .bitcoin)
        viewModel.assetDidChange(balance: nil)
        preferred.resolve(Self.tonOption)
        await awaitEnd(of: holdingsLoad)
        await awaitEnd(of: viewModel.loadTask)

        XCTAssertEqual(source.value.assetId, "btc/mainnet/coin")
        XCTAssertEqual(viewModel.amountSuffix, "BTC")
        XCTAssertEqual(preferred.waitingCount, 0)
    }

    func testAnOpenedPickerIsNotSwitchedUnder() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, source) = makePreferringViewModel(preferred)
        viewModel.onAppear()
        await preferred.waitFor(1)

        viewModel.chooseAsset()
        preferred.resolve(Self.tonOption)
        await awaitEnd(of: viewModel.loadTask)

        XCTAssertEqual(source.value.assetId, Self.usdc.assetId)
        XCTAssertEqual(viewModel.amountSuffix, "USDC")
    }

    func testTheMinimumLandsWhileTheHoldingsStillLoad() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, _) = makePreferringViewModel(preferred, minimum: PerpsFundingMinimum(amount: 3.5, text: "minimum"))
        viewModel.onAppear()
        await preferred.waitFor(1)
        viewModel.setAmount("1")

        await waitUntil(viewModel) { viewModel.warningText != nil }
        XCTAssertEqual(viewModel.warningText, "minimum")
        XCTAssertFalse(viewModel.isReviewEnabled)
        preferred.resolve(nil)
    }

    func testAPendingPaymentIsNotSwitchedToTheLargestHolding() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, source) = makePreferringViewModel(preferred, pending: "pending")
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.warningText != nil }
        await awaitEnd(of: viewModel.loadTask)

        XCTAssertEqual(preferred.waitingCount, 0)
        XCTAssertEqual(source.value.assetId, Self.usdc.assetId)
    }

    func testFundingAssetsAreSortedByDollarValueWithStableEmptyHoldings() {
        func option(_ id: String, _ amount: String, _ price: Decimal?) -> PerpsDepositSourceOption {
            .init(
                source: .init(assetId: id, symbol: id, decimals: 8, network: .ethereum),
                balance: .init(amount: amount, usdPrice: price, iconURL: nil)
            )
        }
        let options = [
            option("USDC", "2", 1),
            option("unknown", "100", nil),
            option("TON", "1", 3),
            option("BTC", "0.0001", 60000),
            option("empty", "0", 1),
            option("invalid", "1", .nan),
        ]

        XCTAssertEqual(options.sortedByHoldingValue.map(\.source.assetId), ["BTC", "TON", "USDC", "unknown", "empty", "invalid"])
        XCTAssertEqual(options.sortedByHoldingValue.first, options.largestHolding)
        XCTAssertEqual([options[0], option("tied", "1", 2)].sortedByHoldingValue.map(\.source.assetId), ["USDC", "tied"])
    }

    func testLargestHoldingIsTheMostDollarsHeld() {
        func option(_ id: String, _ amount: String?, _ price: Decimal?) -> PerpsDepositSourceOption {
            PerpsDepositSourceOption(
                source: .init(assetId: id, symbol: id, decimals: 6, network: .ethereum),
                balance: amount.map { .init(amount: $0, usdPrice: price, iconURL: nil) }
            )
        }
        XCTAssertNil([PerpsDepositSourceOption]().largestHolding)
        XCTAssertNil([option("usdc", "0", 1), option("ton", nil, 3), option("x", "100", nil)].largestHolding)
        XCTAssertEqual(
            [option("usdc", "2", 1), option("ton", "1", 3), option("eth", "0.0001", 2000)].largestHolding?.source.assetId,
            "ton"
        )
        XCTAssertEqual([option("usdc", "3", 1), option("ton", "1", 3)].largestHolding?.source.assetId, "usdc")
    }

    private static let usdc = PerpsDepositSource(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum)
    private static let tonOption = PerpsDepositSourceOption(
        source: .init(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, network: .ton),
        balance: .init(amount: "10", usdPrice: 3, iconURL: URL(string: "https://example.com/ton.png"))
    )

    private func makePreferringViewModel(
        _ preferred: HeldLoads<PerpsDepositSourceOption?>,
        pending: String? = nil,
        minimum: PerpsFundingMinimum? = nil
    ) -> (PerpsFundingAmountViewModel<String>, Box<PerpsDepositSource>) {
        let source = Box(Self.usdc)
        let viewModel = PerpsFundingAmountViewModel<String>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { source.value },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: {
                    source.value == Self.tonOption.source ? Self.tonOption.balance : .init(amount: "100", usdPrice: 1, iconURL: nil)
                },
                loadLimit: nil,
                loadMinimum: { minimum },
                loadPreferredAsset: { await preferred.next() },
                selectAsset: { source.value = $0.source },
                review: { _ in "fresh" },
                errorText: { _ in nil }
            ),
            format: .test,
            loadPendingReview: { pending },
            pendingNotice: "Finish the pending payment"
        )
        return (viewModel, source)
    }

    private func makeHeldBalanceViewModel(_ balances: HeldLoads<PerpsFundingBalance?>) -> PerpsFundingAmountViewModel<Void> {
        PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { Self.usdc },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { await balances.next() },
                loadLimit: nil,
                limitIsMaxOnly: true,
                review: { _ in },
                errorText: { _ in nil }
            ),
            format: .test
        )
    }

    private func makeHeldLimitViewModel(
        _ limits: HeldLoads<String?>,
        balance: PerpsFundingBalance? = .init(amount: "1", usdPrice: 2000, iconURL: nil)
    ) -> PerpsFundingAmountViewModel<Void> {
        PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, network: .ethereum) },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { balance },
                loadLimit: { await limits.next() },
                limitIsMaxOnly: true,
                review: { _ in },
                errorText: { _ in nil }
            ),
            format: .test
        )
    }

    private func makeEthDepositViewModel(
        maximum: String,
        review: @escaping (String) async -> Void
    ) -> PerpsFundingAmountViewModel<Void> {
        PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, network: .ethereum) },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { .init(amount: "0.00125", usdPrice: 2000, iconURL: nil) },
                loadLimit: { maximum },
                limitIsMaxOnly: true,
                review: review,
                errorText: { _ in nil }
            ),
            format: .test
        )
    }

    private func makeViewModel(
        balance: String?,
        limit: String?,
        format: PerpsFormatting = .test
    ) -> PerpsFundingAmountViewModel<Void> {
        PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum) },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { balance.map { .init(amount: $0, usdPrice: 1, iconURL: nil) } },
                loadLimit: limit.map { value in { value } },
                review: { _ in },
                errorText: { _ in nil }
            ),
            format: format
        )
    }

    private func makeWithdrawViewModel(
        destinationPrice: Decimal? = 50000,
        review: @escaping (String) -> Void
    ) -> PerpsFundingAmountViewModel<String> {
        let destination = PerpsDepositSourceOption(
            source: .init(assetId: "btc/mainnet/coin", symbol: "BTC", decimals: 8, network: .bitcoin),
            balance: .init(amount: "0.5", usdPrice: destinationPrice, iconURL: nil)
        )
        return PerpsFundingAmountViewModel<String>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "lighter/mainnet/usdc", symbol: "USDC", decimals: 6, network: .ethereum) },
                loadDestination: { destination },
                initialUnit: .usd,
                fixedUsdPrice: 1,
                loadBalance: { .init(amount: "1000", usdPrice: 1, iconURL: nil) },
                loadLimit: nil,
                review: { amount in
                    review(amount)
                    return amount
                },
                errorText: { _ in nil }
            ),
            format: .test
        )
    }

    private func load(_ viewModel: PerpsFundingAmountViewModel<some Any>) async {
        viewModel.onAppear()
        await viewModel.loadTask?.value
    }

    private func awaitEnd(of load: Task<Void, Never>?) async {
        let ended = expectation(description: "the load ends without another held call")
        Task {
            await load?.value
            ended.fulfill()
        }
        await fulfillment(of: [ended], timeout: 5)
    }
}

private final class Box<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

/// Loads held until the test resolves them, oldest first.
@MainActor
private final class HeldLoads<Value: Sendable> {
    private var waiting: [CheckedContinuation<Value, Never>] = []
    private let changes = TestSignal()

    func next() async -> Value {
        await withCheckedContinuation {
            waiting.append($0)
            changes.send()
        }
    }

    var waitingCount: Int {
        waiting.count
    }

    func waitFor(_ count: Int) async {
        await waitUntil(changes) { self.waiting.count >= count }
    }

    func resolve(_ value: Value) {
        waiting.removeFirst().resume(returning: value)
    }
}
