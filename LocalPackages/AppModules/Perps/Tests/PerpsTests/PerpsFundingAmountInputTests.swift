@testable import Perps
import PerpsModels
import XCTest

final class PerpsFundingAmountInputTests: XCTestCase {
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
    func testWithdrawalDisplaysDestinationIconWhileAmountStaysInUSDC() async throws {
        let iconURL = try XCTUnwrap(URL(string: "https://example.com/btc.png"))
        let viewModel = PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "lighter/mainnet/usdc", symbol: "USDC", decimals: 6, network: .ethereum) },
                displayAsset: { balance in
                    .init(assetId: "btc/mainnet/coin", symbol: "BTC", network: .bitcoin, iconURL: balance?.iconURL, balanceText: nil)
                },
                initialUnit: .usd,
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
        XCTAssertEqual(viewModel.amountSuffix, "USDC")
        XCTAssertEqual(viewModel.amountText, "2")
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
        for _ in 0 ..< 100 where viewModel.warningText == nil {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.warningText, "minimum")
        XCTAssertFalse(viewModel.isReviewEnabled)

        viewModel.setAmount("3.5")
        XCTAssertNil(viewModel.warningText)
        XCTAssertTrue(viewModel.isReviewEnabled)

        viewModel.setAmount("")
        XCTAssertNil(viewModel.warningText)
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
        XCTAssertEqual(viewModel.availableText, PerpsFundingText.missing)
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
        for _ in 0 ..< 100 where !viewModel.isReviewEnabled {
            await Task.yield()
        }

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
        for _ in 0 ..< 100 where viewModel.warningText == nil {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.asset.assetId, "ton/mainnet/coin")
        XCTAssertEqual(viewModel.amountSuffix, "TON")
        viewModel.setAmount("1.1234567")
        XCTAssertEqual(viewModel.amountText, "1.1234567")
    }

    func testReviewCompletionAfterLeavingTheFormIsIgnored() async {
        var release: CheckedContinuation<Void, Never>?
        let started = expectation(description: "review started")
        let finished = expectation(description: "review finished")
        let reviewed = expectation(description: "reviewed")
        reviewed.isInverted = true
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
                    finished.fulfill()
                    return "late"
                },
                errorText: { _ in nil }
            ),
            format: .test
        )
        viewModel.onReviewed = { _ in reviewed.fulfill() }
        viewModel.setAmount("1")
        viewModel.review()
        await fulfillment(of: [started], timeout: 1)

        viewModel.onDisappear()
        release?.resume()
        await fulfillment(of: [finished, reviewed], timeout: 1)
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
        viewModel.assetDidChange(balance: listed)

        XCTAssertEqual(viewModel.asset.iconURL, listed.iconURL)
        XCTAssertNotEqual(viewModel.availableText, PerpsFundingText.missing)
        XCTAssertEqual(viewModel.amountSuffix, "BTC")
        XCTAssertEqual(viewModel.amountText, "")

        await loads.waitFor(2)
        loads.resolve(.init(amount: "10", usdPrice: 1, iconURL: nil))
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.balance, listed)

        let loaded = PerpsFundingBalance(amount: "0.6", usdPrice: 60000, iconURL: listed.iconURL)
        loads.resolve(loaded)
        for _ in 0 ..< 200 where viewModel.balance != loaded {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
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
        for _ in 0 ..< 200 where viewModel.isMaxPending {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
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
        for _ in 0 ..< 200 where viewModel.limit == nil {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(viewModel.amountText, "0.1")
    }

    func testDepositStartsFromTheLargestHoldingOnceListed() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, source) = makePreferringViewModel(preferred)
        viewModel.onAppear()
        await preferred.waitFor(1)
        XCTAssertEqual(viewModel.amountSuffix, "USDC")

        preferred.resolve(Self.tonOption)
        for _ in 0 ..< 200 where viewModel.amountSuffix != "TON" {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(source.value.assetId, "ton/mainnet/coin")
        XCTAssertEqual(viewModel.asset.iconURL, Self.tonOption.balance?.iconURL)
        XCTAssertEqual(viewModel.balance, Self.tonOption.balance)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(preferred.waitingCount, 0)
    }

    func testDepositKeepsItsAssetOnceTheUserHasStartedTyping() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, source) = makePreferringViewModel(preferred)
        viewModel.onAppear()
        await preferred.waitFor(1)
        viewModel.setAmount("5")

        preferred.resolve(Self.tonOption)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(source.value.assetId, Self.usdc.assetId)
        XCTAssertEqual(viewModel.amountText, "5")
        XCTAssertEqual(viewModel.amountSuffix, "USDC")
    }

    func testAnAssetPickedWhileTheHoldingsLoadIsNotReplaced() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, source) = makePreferringViewModel(preferred)
        viewModel.onAppear()
        await preferred.waitFor(1)

        source.value = PerpsDepositSource(assetId: "btc/mainnet/coin", symbol: "BTC", decimals: 8, network: .bitcoin)
        viewModel.assetDidChange(balance: nil)
        preferred.resolve(Self.tonOption)
        try? await Task.sleep(nanoseconds: 50_000_000)

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
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(source.value.assetId, Self.usdc.assetId)
        XCTAssertEqual(viewModel.amountSuffix, "USDC")
    }

    func testTheMinimumLandsWhileTheHoldingsStillLoad() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, _) = makePreferringViewModel(preferred, minimum: PerpsFundingMinimum(amount: 3.5, text: "minimum"))
        viewModel.onAppear()
        await preferred.waitFor(1)
        viewModel.setAmount("1")

        for _ in 0 ..< 200 where viewModel.warningText == nil {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(viewModel.warningText, "minimum")
        XCTAssertFalse(viewModel.isReviewEnabled)
        preferred.resolve(nil)
    }

    func testAPendingPaymentIsNotSwitchedToTheLargestHolding() async {
        let preferred = HeldLoads<PerpsDepositSourceOption?>()
        let (viewModel, source) = makePreferringViewModel(preferred, pending: "pending")
        viewModel.onAppear()
        for _ in 0 ..< 100 where viewModel.warningText == nil {
            await Task.yield()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(preferred.waitingCount, 0)
        XCTAssertEqual(source.value.assetId, Self.usdc.assetId)
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

    private func makeHeldLimitViewModel(_ limits: HeldLoads<String?>) -> PerpsFundingAmountViewModel<Void> {
        PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, network: .ethereum) },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { .init(amount: "1", usdPrice: 2000, iconURL: nil) },
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

    private func makeViewModel(balance: String?, limit: String?) -> PerpsFundingAmountViewModel<Void> {
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
            format: .test
        )
    }

    private func load(_ viewModel: PerpsFundingAmountViewModel<some Any>) async {
        viewModel.onAppear()
        for _ in 0 ..< 100 where viewModel.limit == nil && viewModel.balance == nil {
            await Task.yield()
        }
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

    func next() async -> Value {
        await withCheckedContinuation { waiting.append($0) }
    }

    var waitingCount: Int {
        waiting.count
    }

    func waitFor(_ count: Int) async {
        for _ in 0 ..< 200 where waiting.count < count {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    func resolve(_ value: Value) {
        waiting.removeFirst().resume(returning: value)
    }
}
