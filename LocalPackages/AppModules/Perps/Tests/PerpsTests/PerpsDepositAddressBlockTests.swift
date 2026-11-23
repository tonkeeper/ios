@testable import Perps
import PerpsModels
import TKTestSupport
import XCTest

@MainActor
final class PerpsDepositAddressBlockTests: XCTestCase {
    private struct Blocked: Error {}
    private struct Refused: Error {}

    private let tron = PerpsDepositSource(assetId: "tron/mainnet/coin", symbol: "TRX", decimals: 6, network: .tron)
    private let usdt = PerpsDepositSource(assetId: "tron/mainnet/jetton/usdt", symbol: "USDT", decimals: 6, network: .tron)

    func testABlockFoundOnOpeningShowsForEveryAmountOnceOneIsTyped() async {
        var reports: [String] = []
        let viewModel = makeViewModel(probe: { _ in throw Blocked() }) { reports.append(Self.describe($0)) }
        await load(viewModel)

        XCTAssertNil(viewModel.warningText)
        XCTAssertEqual(reports, ["background"])

        for amount in ["5", "200"] {
            viewModel.setAmount(amount)
            XCTAssertEqual(viewModel.warningText, "blocked", amount)
            XCTAssertFalse(viewModel.isReviewEnabled, amount)
            XCTAssertNil(viewModel.quoteKey, amount)
        }

        viewModel.toggleUnit()
        viewModel.setAmount("3")
        XCTAssertEqual(viewModel.warningText, "blocked")

        viewModel.setMax()
        XCTAssertEqual(viewModel.warningText, "blocked")
        XCTAssertFalse(viewModel.isReviewEnabled)

        for amount in ["", "0"] {
            viewModel.setAmount(amount)
            XCTAssertNil(viewModel.warningText, amount)
            XCTAssertNil(viewModel.refusalKey, amount)
        }
    }

    func testTheBlockOffersAnotherWalletInsteadOfReview() async {
        var reports: [String] = []
        var quotes = 0
        var chosen = 0
        let viewModel = makeViewModel(
            probe: { _ in throw Blocked() },
            review: { _ in quotes += 1 }
        ) { reports.append(Self.describe($0)) }
        await load(viewModel)

        viewModel.setAmount("5")
        XCTAssertFalse(viewModel.offersAnotherWallet, "nothing to open it with: the only wallet, or a withdrawal")
        XCTAssertFalse(viewModel.isReviewEnabled, "the only wallet keeps an inactive Review")

        viewModel.onChooseAnotherWallet = { chosen += 1 }
        XCTAssertTrue(viewModel.offersAnotherWallet)
        viewModel.chooseAnotherWallet()
        viewModel.review()
        await viewModel.reportRefusal()

        XCTAssertEqual(chosen, 1)
        XCTAssertEqual(quotes, 0)
        XCTAssertEqual(reports, ["background", "refused addressBlocked"], "the tap reports the amount at once, and only once")

        for amount in ["", "0"] {
            viewModel.setAmount(amount)
            XCTAssertFalse(viewModel.offersAnotherWallet, amount)
            viewModel.chooseAnotherWallet()
        }
        XCTAssertEqual(chosen, 1)
    }

    func testEachBlockedAmountIsReportedAfterThePause() async {
        var reports: [String] = []
        let viewModel = makeViewModel(probe: { _ in throw Blocked() }) { reports.append(Self.describe($0)) }
        await load(viewModel)

        viewModel.setAmount("5")
        await viewModel.reportRefusal()
        viewModel.setAmount("6")
        await viewModel.reportRefusal()

        XCTAssertEqual(reports, ["background", "refused addressBlocked", "refused addressBlocked"])
    }

    func testABlockOnTheTypedAmountsQuoteIsKeptForTheAssetAndReportedOnce() async {
        var reports: [String] = []
        var quotes = 0
        let viewModel = makeViewModel(review: { _ in
            quotes += 1
            throw Blocked()
        }) { reports.append(Self.describe($0)) }
        await load(viewModel)

        viewModel.setAmount("5")
        await viewModel.updateQuote()
        XCTAssertEqual(viewModel.warningText, "blocked")
        XCTAssertFalse(viewModel.isReviewEnabled)
        XCTAssertNil(viewModel.quoteLine)
        await viewModel.reportRefusal()

        viewModel.setAmount("6")
        await viewModel.updateQuote()
        XCTAssertEqual(viewModel.warningText, "blocked")
        XCTAssertEqual(quotes, 1)
        XCTAssertEqual(reports, ["refused addressBlocked"])
    }

    func testABlockOnReviewIsKeptAndNotReportedAsAFailure() async {
        var reports: [String] = []
        var reviewed = 0
        let viewModel = makeViewModel(review: { _ in throw Blocked() }) { reports.append(Self.describe($0)) }
        viewModel.onReviewed = { _ in reviewed += 1 }
        await load(viewModel)

        viewModel.setAmount("5")
        viewModel.review()
        await viewModel.reviewTask?.value

        XCTAssertEqual(viewModel.warningText, "blocked")
        XCTAssertFalse(viewModel.isReviewEnabled)
        XCTAssertEqual(reviewed, 0)
        XCTAssertEqual(reports, ["tap"])
    }

    func testAReviewThatLandsAfterTheBlockDoesNotOpenTheConfirmation() async {
        let probe = TestGate()
        let review = TestGate()
        var reviewed = 0
        let viewModel = makeViewModel(
            probe: { _ in
                try await probe.wait()
                throw Blocked()
            },
            review: { _ in try await review.wait() },
            report: { _ in }
        )
        viewModel.onReviewed = { _ in reviewed += 1 }
        viewModel.onChooseAnotherWallet = {}
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.availableText != nil }

        viewModel.setAmount("5")
        viewModel.review()
        await probe.open()
        await viewModel.loadTask?.value
        XCTAssertTrue(viewModel.offersAnotherWallet)
        await review.open()
        await viewModel.reviewTask?.value

        XCTAssertEqual(reviewed, 0)
        XCTAssertEqual(viewModel.warningText, "blocked")
    }

    func testABlockFoundAfterAFailedReviewReplacesItsError() async {
        let probe = TestGate()
        var reports: [String] = []
        let viewModel = makeViewModel(
            probe: { _ in
                try await probe.wait()
                throw Blocked()
            },
            review: { _ in throw Refused() }
        ) { reports.append(Self.describe($0)) }
        viewModel.onChooseAnotherWallet = {}
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.availableText != nil }

        viewModel.setAmount("5")
        viewModel.review()
        await viewModel.reviewTask?.value
        XCTAssertEqual(viewModel.warningText, "refused")
        XCTAssertFalse(viewModel.offersAnotherWallet)

        await probe.open()
        await viewModel.loadTask?.value
        await viewModel.reportRefusal()

        XCTAssertEqual(viewModel.warningText, "blocked")
        XCTAssertTrue(viewModel.offersAnotherWallet)
        XCTAssertEqual(reports, ["tap", "failed", "background", "refused addressBlocked"])
    }

    func testAReviewThatFailsAfterTheBlockLeavesTheBlock() async {
        let probe = TestGate()
        let review = TestGate()
        var reports: [String] = []
        let viewModel = makeViewModel(
            probe: { _ in
                try await probe.wait()
                throw Blocked()
            },
            review: { _ in
                try await review.wait()
                throw Refused()
            }
        ) { reports.append(Self.describe($0)) }
        viewModel.onChooseAnotherWallet = {}
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.availableText != nil }

        viewModel.setAmount("5")
        viewModel.review()
        await probe.open()
        await viewModel.loadTask?.value
        await review.open()
        await viewModel.reviewTask?.value

        XCTAssertEqual(viewModel.warningText, "blocked")
        XCTAssertTrue(viewModel.offersAnotherWallet)
        XCTAssertEqual(reports, ["tap", "background"])
    }

    func testABlockFoundWithNoAmountKeepsThePendingPaymentError() async {
        let viewModel = makeViewModel(
            probe: { _ in throw Blocked() },
            loadPendingReview: { throw Refused() },
            report: { _ in }
        )
        await load(viewModel)

        XCTAssertEqual(viewModel.warningText, "refused")

        viewModel.setAmount("5")
        XCTAssertEqual(viewModel.warningText, "blocked")
    }

    func testALateProbeDoesNotReportABlockAlreadyFoundByTheTypedQuote() async {
        let probe = TestGate()
        var reports: [String] = []
        let viewModel = makeViewModel(
            probe: { _ in
                try await probe.wait()
                throw Blocked()
            },
            review: { _ in throw Blocked() }
        ) { reports.append(Self.describe($0)) }
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.availableText != nil }

        viewModel.setAmount("5")
        await viewModel.updateQuote()
        await viewModel.reportRefusal()
        await probe.open()
        await viewModel.loadTask?.value

        XCTAssertEqual(viewModel.warningText, "blocked")
        XCTAssertEqual(reports, ["refused addressBlocked"])
    }

    func testAResumedPaymentIsNotHeldBackByTheBlock() async {
        var reviewed = 0
        var reports: [String] = []
        let viewModel = makeViewModel(probe: { _ in throw Blocked() }, pendingReview: true) { reports.append(Self.describe($0)) }
        viewModel.onReviewed = { _ in reviewed += 1 }
        viewModel.onChooseAnotherWallet = {}
        await load(viewModel)

        XCTAssertEqual(viewModel.warningText, "resuming")
        XCTAssertFalse(viewModel.offersAnotherWallet)
        XCTAssertEqual(reports, [])
        XCTAssertTrue(viewModel.isReviewEnabled)
        viewModel.review()

        XCTAssertEqual(reviewed, 1)
    }

    func testTheBlockStaysWithItsAssetAndTheOpeningIsReportedOnce() async {
        var reports: [String] = []
        let asset = AssetBox(tron)
        let viewModel = makeViewModel(
            asset: asset,
            probe: { [tron] assetId in
                if assetId == tron.assetId { throw Blocked() }
                return nil
            }
        ) { reports.append(Self.describe($0)) }
        await load(viewModel)

        asset.value = usdt
        viewModel.assetDidChange(balance: .init(amount: "100", usdPrice: 1, iconURL: nil))
        await viewModel.loadTask?.value
        viewModel.onChooseAnotherWallet = {}
        viewModel.setAmount("5")
        XCTAssertNil(viewModel.warningText)
        XCTAssertTrue(viewModel.isReviewEnabled)
        XCTAssertFalse(viewModel.offersAnotherWallet)

        asset.value = tron
        viewModel.assetDidChange(balance: .init(amount: "100", usdPrice: 0.5, iconURL: nil))
        await viewModel.loadTask?.value
        viewModel.onDisappear()
        await load(viewModel)
        viewModel.setAmount("5")

        XCTAssertEqual(viewModel.warningText, "blocked")
        XCTAssertEqual(reports, ["background"])
    }

    func testAnotherProbeFailureIsNoBlock() async {
        var reports: [String] = []
        let viewModel = makeViewModel(probe: { _ in throw Refused() }) { reports.append(Self.describe($0)) }
        await load(viewModel)

        viewModel.setAmount("5")

        XCTAssertNil(viewModel.warningText)
        XCTAssertTrue(viewModel.isReviewEnabled)
        XCTAssertEqual(reports, [])
    }

    private final class AssetBox {
        var value: PerpsDepositSource
        init(_ value: PerpsDepositSource) {
            self.value = value
        }
    }

    private func makeViewModel(
        asset: AssetBox? = nil,
        probe: ((String) async throws -> PerpsFundingMinimum?)? = nil,
        pendingReview: Bool = false,
        loadPendingReview: (() async throws -> Void?)? = nil,
        review: @escaping (String) async throws -> Void = { _ in },
        report: @escaping (PerpsFundingAmountReport) -> Void
    ) -> PerpsFundingAmountViewModel<Void> {
        let asset = asset ?? AssetBox(tron)
        return PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { asset.value },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { .init(amount: "100", usdPrice: 0.5, iconURL: nil) },
                loadLimit: nil,
                loadMinimum: probe.map { probe in { try await probe(asset.value.assetId) } },
                review: review,
                errorText: { $0 is Blocked ? "blocked" : "refused" },
                blocksAsset: { $0 is Blocked },
                quote: { _ in nil },
                report: report
            ),
            format: .test,
            loadPendingReview: loadPendingReview ?? (pendingReview ? { () } : nil),
            pendingNotice: "resuming",
            quoteDebounce: 0
        )
    }

    private func load(_ viewModel: PerpsFundingAmountViewModel<Void>) async {
        viewModel.onAppear()
        await viewModel.loadTask?.value
    }

    private static func describe(_ report: PerpsFundingAmountReport) -> String {
        switch report {
        case .reviewTapped: "tap"
        case let .refused(refusal): "refused \(refusal)"
        case .blockedInBackground: "background"
        case .failed: "failed"
        case .unreadableQuote: "unreadable"
        }
    }
}
