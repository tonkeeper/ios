@testable import Perps
import PerpsModels
import XCTest

@MainActor
final class PerpsDepositRegionRestrictionTests: XCTestCase {
    private struct Restricted: Error {}
    private struct Refused: Error {}

    private let tron = PerpsDepositSource(assetId: "tron/mainnet/coin", symbol: "TRX", decimals: 6, network: .tron)

    func testARegionRefusalOnOpeningLeavesTheFormOnce() async {
        var reports: [String] = []
        var left = 0
        let viewModel = makeViewModel(
            probe: { throw Restricted() },
            review: { _ in throw Restricted() }
        ) { reports.append(Self.describe($0)) }
        viewModel.onRegionRestricted = { left += 1 }

        viewModel.onAppear()
        await viewModel.loadTask?.value
        XCTAssertEqual(left, 1)

        viewModel.setAmount("5")
        await viewModel.updateQuote()
        viewModel.review()
        await viewModel.reviewTask?.value

        XCTAssertEqual(left, 1)
        XCTAssertNil(viewModel.warningText)
        XCTAssertEqual(reports, ["tap"])
    }

    func testARegionRefusalOfTheReviewedAmountLeavesTheForm() async {
        var reports: [String] = []
        var left = 0
        var reviewed = 0
        let viewModel = makeViewModel(review: { _ in throw Restricted() }) { reports.append(Self.describe($0)) }
        viewModel.onRegionRestricted = { left += 1 }
        viewModel.onReviewed = { _ in reviewed += 1 }
        viewModel.onAppear()
        await viewModel.loadTask?.value

        viewModel.setAmount("5")
        viewModel.review()
        await viewModel.reviewTask?.value

        XCTAssertEqual(left, 1)
        XCTAssertEqual(reviewed, 0)
        XCTAssertNil(viewModel.warningText)
        XCTAssertEqual(reports, ["tap"])
    }

    func testAProbeRefusalWhileResumingAPaymentKeepsTheResume() async {
        var left = 0
        var reviewed = 0
        let viewModel = makeViewModel(
            probe: { throw Restricted() },
            loadPendingReview: { () },
            review: { _ in throw Restricted() }
        ) { _ in }
        viewModel.onRegionRestricted = { left += 1 }
        viewModel.onReviewed = { _ in reviewed += 1 }

        viewModel.onAppear()
        await viewModel.loadTask?.value
        viewModel.review()

        XCTAssertEqual(left, 0)
        XCTAssertEqual(reviewed, 1)
    }

    func testACoveredFormLeavesOnlyOnceItIsBack() async {
        var left = 0
        let viewModel = makeViewModel(review: { _ in throw Restricted() }) { _ in }
        viewModel.onRegionRestricted = { left += 1 }
        viewModel.onAppear()
        await viewModel.loadTask?.value
        viewModel.setAmount("5")

        viewModel.onDisappear()
        await viewModel.updateQuote()
        XCTAssertEqual(left, 0)

        viewModel.onAppear()
        await viewModel.loadTask?.value
        viewModel.review()
        await viewModel.reviewTask?.value
        XCTAssertEqual(left, 1)
    }

    func testAnotherRefusalStaysOnTheForm() async {
        var left = 0
        let viewModel = makeViewModel(review: { _ in throw Refused() }) { _ in }
        viewModel.onRegionRestricted = { left += 1 }
        viewModel.onAppear()
        await viewModel.loadTask?.value

        viewModel.setAmount("5")
        viewModel.review()
        await viewModel.reviewTask?.value

        XCTAssertEqual(left, 0)
        XCTAssertEqual(viewModel.warningText, "refused")
    }

    private func makeViewModel(
        probe: (() async throws -> PerpsFundingMinimum?)? = nil,
        loadPendingReview: (() async throws -> Void?)? = nil,
        review: @escaping (String) async throws -> Void,
        report: @escaping (PerpsFundingAmountReport) -> Void
    ) -> PerpsFundingAmountViewModel<Void> {
        PerpsFundingAmountViewModel<Void>(
            config: PerpsFundingAmountConfig(
                title: "",
                asset: { [tron] in tron },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { .init(amount: "100", usdPrice: 0.5, iconURL: nil) },
                loadLimit: nil,
                loadMinimum: probe,
                review: review,
                errorText: { $0 is Restricted ? nil : "refused" },
                isRegionRestricted: { $0 is Restricted },
                quote: { _ in nil },
                report: report
            ),
            format: .test,
            loadPendingReview: loadPendingReview,
            quoteDebounce: 0
        )
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
