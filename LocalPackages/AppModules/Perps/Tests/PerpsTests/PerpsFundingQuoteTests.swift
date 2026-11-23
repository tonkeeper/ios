@testable import Perps
import PerpsModels
import XCTest

@MainActor
final class PerpsFundingQuoteTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testTypedAmountShowsWhatLandsAndTheFee() async {
        let quotes = Quotes()
        let viewModel = makeViewModel(quotes)
        XCTAssertNil(viewModel.quoteLine)

        viewModel.setAmount("2")
        XCTAssertEqual(viewModel.quoteLine, .fetching)
        await viewModel.updateQuote()

        XCTAssertEqual(viewModel.quoteLine, .quoted(received: usd("1.97"), fee: usd("0.03")))
        XCTAssertEqual(quotes.amounts, ["2"])
    }

    func testReviewPaysTheShownQuoteOnce() async {
        let quotes = Quotes()
        let viewModel = makeViewModel(quotes)
        var reviewed: [Review] = []
        viewModel.onReviewed = { reviewed.append($0) }
        viewModel.setAmount("2")
        await viewModel.updateQuote()

        viewModel.review()
        XCTAssertEqual(quotes.amounts, ["2"])
        XCTAssertEqual(reviewed.map(\.amount), ["2"])

        await viewModel.updateQuote()
        XCTAssertEqual(quotes.amounts, ["2", "2"], "a quote handed to the confirmation is asked for again")
    }

    func testQuoteAboutToExpireIsReviewedAgain() async {
        let quotes = Quotes(expiresIn: 45)
        let viewModel = makeViewModel(quotes)
        var reviewed: [Review] = []
        viewModel.onReviewed = { reviewed.append($0) }
        viewModel.setAmount("2")
        await viewModel.updateQuote()

        viewModel.review()
        for _ in 0 ..< 100 where reviewed.isEmpty {
            await Task.yield()
        }

        XCTAssertEqual(quotes.amounts, ["2", "2"])
        XCTAssertEqual(reviewed.map(\.amount), ["2"])
    }

    func testReviewDuringTheQuoteKeepsWhatItPricedOnTheLine() async throws {
        let quotes = Quotes()
        quotes.holdsAmount = "2"
        let viewModel = makeViewModel(quotes)
        var reviewed: [Review] = []
        viewModel.onReviewed = { reviewed.append($0) }
        viewModel.setAmount("2")
        let live = Task { await viewModel.updateQuote() }
        for _ in 0 ..< 100 where quotes.held == nil {
            await Task.yield()
        }

        quotes.holdsAmount = nil
        quotes.discount = try XCTUnwrap(Decimal(string: "0.01"))
        viewModel.review()
        for _ in 0 ..< 100 where reviewed.isEmpty {
            await Task.yield()
        }
        quotes.discount = 0
        quotes.held?.resume()
        await live.value

        XCTAssertEqual(viewModel.quoteLine, .quoted(received: usd("1.96"), fee: usd("0.03")), "the line shows what the confirmation shows")
        viewModel.review()
        for _ in 0 ..< 100 where reviewed.count < 2 {
            await Task.yield()
        }
        XCTAssertEqual(quotes.amounts, ["2", "2", "2"], "a quote handed to the confirmation is asked for again")
    }

    func testQuoteOfAnEarlierAmountIsNeitherShownNorPaid() async {
        let quotes = Quotes()
        let viewModel = makeViewModel(quotes)
        var reviewed: [Review] = []
        viewModel.onReviewed = { reviewed.append($0) }
        viewModel.setAmount("2")
        await viewModel.updateQuote()

        viewModel.setAmount("3")
        XCTAssertEqual(viewModel.quoteLine, .fetching)
        viewModel.review()
        for _ in 0 ..< 100 where reviewed.isEmpty {
            await Task.yield()
        }

        XCTAssertEqual(reviewed.map(\.amount), ["3"])
    }

    func testCancelledQuoteCannotReplaceTheNewerOne() async {
        let quotes = Quotes()
        quotes.holdsAmount = "2"
        let viewModel = makeViewModel(quotes)
        viewModel.setAmount("2")
        let stale = Task { await viewModel.updateQuote() }
        for _ in 0 ..< 100 where quotes.held == nil {
            await Task.yield()
        }

        viewModel.setAmount("3")
        stale.cancel()
        await viewModel.updateQuote()
        quotes.held?.resume()
        await stale.value

        XCTAssertEqual(viewModel.quoteLine, .quoted(received: usd("2.97"), fee: usd("0.03")))
    }

    func testFailedQuoteNamesTheErrorInItsPlace() async {
        let quotes = Quotes()
        quotes.fails = true
        let viewModel = makeViewModel(quotes)
        viewModel.setAmount("2")
        await viewModel.updateQuote()

        XCTAssertEqual(viewModel.quoteLine, .failed("No route"))
        XCTAssertNil(viewModel.warningText)
    }

    func testDepositFeeIsLeftOutWherePartOfItHasNoDollars() throws {
        let fees = try PerpsDepositProviderFees(destinationGasUsd: XCTUnwrap(Decimal(string: "0.02")), providerUsd: XCTUnwrap(Decimal(string: "0.05")))
        let priced = try XCTUnwrap(PerpsFundingQuote(deposit: terms(networkFeeUsd: Decimal(string: "0.01"), providerFees: fees)))
        XCTAssertEqual(priced.receivedUsd, Decimal(string: "1.9"))
        XCTAssertEqual(priced.feeUsd, Decimal(string: "0.08"))

        XCTAssertNil(PerpsFundingQuote(deposit: terms(networkFeeUsd: nil, providerFees: fees))?.feeUsd)
        XCTAssertNil(PerpsFundingQuote(deposit: terms(networkFeeUsd: 1, providerFees: nil))?.feeUsd)
        XCTAssertNil(PerpsFundingQuote(deposit: terms(networkFeeUsd: 1, providerFees: fees, paysFeeInCharges: true))?.feeUsd)
    }

    private func makeViewModel(_ quotes: Quotes) -> PerpsFundingAmountViewModel<Review> {
        PerpsFundingAmountViewModel(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum) },
                initialUnit: .token,
                fixedUsdPrice: 1,
                loadBalance: { nil },
                loadLimit: nil,
                review: { [now] amount in try await quotes.review(amount, now: now) },
                errorText: { _ in "No route" },
                quote: { PerpsFundingQuote(receivedUsd: $0.received, feeUsd: $0.fee, expiresAt: $0.expiresAt) }
            ),
            format: .test,
            quoteDebounce: 0,
            now: { [now] in now }
        )
    }

    private func usd(_ value: String) -> String {
        PerpsFormatting.test.usd(value)
    }

    private func terms(networkFeeUsd: Decimal?, providerFees: PerpsDepositProviderFees?, paysFeeInCharges: Bool = false) -> PerpsDepositTerms {
        PerpsDepositTerms(
            sourceAmount: "2", sourceSymbol: "USDT", creditedAmount: "1.9", creditedSymbol: "USDC",
            networkFee: "0.001", networkFeeSymbol: "ETH", networkFeeUsd: networkFeeUsd,
            paysFeeInCharges: paysFeeInCharges, providerFees: providerFees
        )
    }
}

private final class Review {
    let amount: String
    let received: Decimal
    let fee: Decimal?
    let expiresAt: Date?

    init(amount: String, received: Decimal, fee: Decimal?, expiresAt: Date?) {
        self.amount = amount
        self.received = received
        self.fee = fee
        self.expiresAt = expiresAt
    }
}

private struct QuoteFailure: Error {}

@MainActor
private final class Quotes {
    private let expiresIn: TimeInterval
    private(set) var amounts: [String] = []
    var fails = false
    /// Taken off what lands, so two reviews of one amount tell apart.
    var discount: Decimal = 0
    /// The review of this amount waits in `held` until the test resumes it.
    var holdsAmount: String?
    private(set) var held: CheckedContinuation<Void, Never>?

    init(expiresIn: TimeInterval = 120) {
        self.expiresIn = expiresIn
    }

    func review(_ amount: String, now: Date) async throws -> Review {
        amounts.append(amount)
        if amount == holdsAmount {
            await withCheckedContinuation { held = $0 }
        }
        if fails { throw QuoteFailure() }
        let fee = Decimal(string: "0.03")!
        return Review(amount: amount, received: Decimal(string: amount)! - fee - discount, fee: fee, expiresAt: now.addingTimeInterval(expiresIn))
    }
}
