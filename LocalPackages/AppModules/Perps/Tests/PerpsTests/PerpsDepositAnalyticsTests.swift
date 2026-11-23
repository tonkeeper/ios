@testable import Perps
import PerpsModels
import TKTestSupport
import XCTest

private let untilCancelled = TestGate()

@MainActor
final class PerpsDepositAnalyticsTests: XCTestCase {
    private struct Refused: Error {}

    func testATapReportsItsDollarsAndAFailedReviewItsError() async {
        var reports: [String] = []
        let viewModel = makeViewModel(review: { throw Refused() }) { reports.append(Self.describe($0)) }
        await load(viewModel)

        viewModel.setAmount("10")
        viewModel.review()
        await waitUntil(viewModel) { viewModel.errorText != nil }

        XCTAssertEqual(reports, ["tap 5", "failed"])
    }

    func testFinishingASignedPaymentIsNotReportedAsATap() async {
        var reports: [String] = []
        var reviewed = false
        let viewModel = makeViewModel(pendingReview: true) { reports.append(Self.describe($0)) }
        viewModel.onReviewed = { _ in reviewed = true }
        await load(viewModel)

        viewModel.review()

        XCTAssertTrue(reviewed)
        XCTAssertEqual(reports, [])
    }

    func testAFailedLiveQuoteIsReported() async {
        var reports: [String] = []
        let viewModel = makeViewModel(review: { throw Refused() }) { reports.append(Self.describe($0)) }
        await load(viewModel)

        viewModel.setAmount("10")
        await viewModel.updateQuote()

        XCTAssertEqual(viewModel.quoteLine, .failed("refused"))
        XCTAssertEqual(reports, ["failed"])
    }

    func testARefusedAmountIsReportedAfterThePauseAndEachAmountHasItsOwnKey() async {
        var reports: [String] = []
        let viewModel = makeViewModel(minimum: 5) { reports.append(Self.describe($0)) }
        await load(viewModel)

        viewModel.setAmount("200")
        let overBalance = viewModel.refusalKey
        viewModel.setAmount("300")
        XCTAssertNotNil(overBalance)
        XCTAssertNotEqual(viewModel.refusalKey, overBalance)

        viewModel.setAmount("2")
        await waitUntil(viewModel) { viewModel.warningText != nil }
        await viewModel.reportRefusal()

        viewModel.setAmount("50")
        XCTAssertNil(viewModel.refusalKey)
        await viewModel.reportRefusal()

        XCTAssertEqual(reports, ["refused belowMinimum"])
    }

    func testARefusalLeftBeforeThePauseIsNotReported() async {
        var reports: [String] = []
        let viewModel = makeViewModel(quoteDebounce: 60) { reports.append(Self.describe($0)) }
        await load(viewModel)

        viewModel.setAmount("200")
        let pause = Task { await viewModel.reportRefusal() }
        pause.cancel()
        await pause.value

        XCTAssertEqual(reports, [])
    }

    func testOnlyAssetsWorthTheGatewayMinimumCanBeDeposited() {
        let holdings: [(String, Decimal?)] = [("1", 1), ("0.99", 1), ("5", nil)]
        let options = holdings.map { amount, price in
            PerpsDepositSourceOption(
                source: .init(assetId: "tron/mainnet/coin", symbol: "TRX", decimals: 6, network: .tron),
                balance: .init(amount: amount, usdPrice: price, iconURL: nil)
            )
        }

        XCTAssertEqual(options.depositableCount, 1)
    }

    func testACancelledPaymentIsNoFailure() {
        XCTAssertNil(PerpsDepositFailure(.canceled))
        XCTAssertEqual(PerpsDepositFailure(.accountCreationPending), .depositInProgress)
    }

    func testTheStartCarriesTheCountOfAFreshListingOnce() async {
        var sent: [Int?] = []
        let started = TestSignal()
        let option = PerpsDepositSourceOption(
            source: .init(assetId: "tron/mainnet/coin", symbol: "TRX", decimals: 6, network: .tron),
            balance: .init(amount: "10", usdPrice: 0.5, iconURL: nil)
        )
        let listing = PerpsDepositSourceListing(load: { PerpsDepositSources(options: [option], isFresh: true) }) {
            sent.append($0)
            started.send()
        }

        let largest = await listing.largestHolding
        await waitUntil(started) { !sent.isEmpty }

        XCTAssertEqual(largest, option)
        XCTAssertEqual(sent, [1])
    }

    func testAStaleListingStartsWithoutACount() async {
        var sent: [Int?] = []
        let started = TestSignal()
        let listing = PerpsDepositSourceListing(load: { PerpsDepositSources(options: [], isFresh: false) }) {
            sent.append($0)
            started.send()
        }

        _ = await listing.largestHolding
        await waitUntil(started) { !sent.isEmpty }

        XCTAssertEqual(sent, [nil])
    }

    func testAScreenClosedBeforeTheListingStartsWithoutACount() async {
        var sent: [Int?] = []
        let start: Task<Void, Never>?
        do {
            let listing = PerpsDepositSourceListing(load: {
                try? await untilCancelled.wait()
                return PerpsDepositSources(options: [], isFresh: true)
            }) { sent.append($0) }
            start = listing.startTask
        }
        await start?.value

        XCTAssertEqual(sent, [nil])
    }

    func testAnUnreadableLiveQuoteIsReported() async {
        var reports: [String] = []
        let viewModel = makeViewModel { reports.append(Self.describe($0)) }
        await load(viewModel)

        viewModel.setAmount("10")
        await viewModel.updateQuote()

        XCTAssertEqual(reports, ["unreadable"])
    }

    func testTheSameRefusalIsNotReportedAgainWhenTheFormReappears() async {
        var reports: [String] = []
        let viewModel = makeViewModel { reports.append(Self.describe($0)) }
        await load(viewModel)

        viewModel.setAmount("200")
        await viewModel.reportRefusal()
        await viewModel.reportRefusal()
        viewModel.setAmount("20")
        await viewModel.reportRefusal()
        viewModel.setAmount("200")
        await viewModel.reportRefusal()

        XCTAssertEqual(reports, ["refused overBalance", "refused overBalance"])
    }

    private func makeViewModel(
        minimum: Decimal? = nil,
        pendingReview: Bool = false,
        quoteDebounce: TimeInterval = 0,
        review: @escaping () throws -> Void = {},
        report: @escaping (PerpsFundingAmountReport) -> Void
    ) -> PerpsFundingAmountViewModel<Void> {
        PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { .init(assetId: "tron/mainnet/coin", symbol: "TRX", decimals: 6, network: .tron) },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { .init(amount: "100", usdPrice: 0.5, iconURL: nil) },
                loadLimit: nil,
                loadMinimum: minimum.map { amount in { PerpsFundingMinimum(amount: amount, text: "minimum") } },
                review: { _ in try review() },
                errorText: { _ in "refused" },
                quote: { _ in nil },
                report: report
            ),
            format: .test,
            loadPendingReview: pendingReview ? { () } : nil,
            pendingNotice: "resuming",
            quoteDebounce: quoteDebounce
        )
    }

    private func load(_ viewModel: PerpsFundingAmountViewModel<Void>) async {
        viewModel.onAppear()
        await viewModel.loadTask?.value
    }

    private static func describe(_ report: PerpsFundingAmountReport) -> String {
        switch report {
        case let .reviewTapped(usdAmount): "tap \(usdAmount.map { "\($0)" } ?? "nil")"
        case let .refused(refusal): "refused \(refusal)"
        case .blockedInBackground: "background"
        case .failed: "failed"
        case .unreadableQuote: "unreadable"
        }
    }
}
