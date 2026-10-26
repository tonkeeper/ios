@testable import Perps
import PerpsModels
import XCTest

@MainActor
final class PerpsTradeConfirmViewModelTests: XCTestCase {
    func test_autoClosePreviewFailure_usesExistingReview() async throws {
        let context = makeContext()
        let viewModel = PerpsTradeConfirmViewModel(context: context, format: .test)
        for error in [PerpsTradingError.offline, .invalidAmount] {
            let editing = await viewModel.autoCloseEditingContext { intent in
                XCTAssertNil(intent.autoClose)
                return .failure(error)
            }
            XCTAssertEqual(try XCTUnwrap(editing).review, context.review)
            XCTAssertEqual(editing?.intent, context.intent)
        }
        XCTAssertEqual(viewModel.openConfirmContext?.review, context.review)
    }

    func test_autoClosePreviewSuccess_doesNotChangeTheDisplayedReview() async throws {
        let context = makeContext()
        let viewModel = PerpsTradeConfirmViewModel(context: context, format: .test)
        let values = viewModel.rows.map(\.value)
        let refreshed = makeContext(entryPrice: 120).review
        let editing = await viewModel.autoCloseEditingContext { _ in .success(refreshed) }
        XCTAssertEqual(try XCTUnwrap(editing).review, refreshed)
        XCTAssertEqual(viewModel.openConfirmContext?.review, context.review)
        XCTAssertEqual(viewModel.rows.map(\.value), values)

        viewModel.updateOpenAutoClose(editing?.intent.autoClose, review: editing?.review)
        XCTAssertEqual(viewModel.openConfirmContext?.review, refreshed)
    }

    func test_editAutoClose_blocksOverlappingRequestsAndConfirmation_thenAllowsRetry() async {
        let viewModel = PerpsTradeConfirmViewModel(context: makeContext(), format: .test)
        let started = expectation(description: "preview started")
        let finished = expectation(description: "preview finished")
        var continuation: CheckedContinuation<Void, Never>?
        var edits = 0
        var confirmations = 0
        viewModel.onConfirm = { confirmations += 1 }
        viewModel.onEditAutoClose = {
            edits += 1
            await withCheckedContinuation {
                continuation = $0
                started.fulfill()
            }
            finished.fulfill()
        }
        viewModel.editAutoClose()
        viewModel.editAutoClose()
        await fulfillment(of: [started], timeout: 1)
        viewModel.editAutoClose()
        viewModel.confirm()
        XCTAssertEqual(edits, 1)
        XCTAssertEqual(confirmations, 0)
        continuation?.resume()
        await fulfillment(of: [finished], timeout: 1)

        let retried = expectation(description: "preview retried")
        viewModel.onEditAutoClose = {
            edits += 1
            retried.fulfill()
        }
        viewModel.editAutoClose()
        await fulfillment(of: [retried], timeout: 1)
        XCTAssertEqual(edits, 2)
    }

    func test_autoClosePreview_discardsAResultAfterTheIntentChanges() async {
        let viewModel = PerpsTradeConfirmViewModel(context: makeContext(), format: .test)
        let editing = await viewModel.autoCloseEditingContext { _ in
            viewModel.updateOpenAutoClose(nil)
            return .success(self.makeContext(entryPrice: 120).review)
        }
        XCTAssertNil(editing)
        XCTAssertEqual(viewModel.openConfirmContext?.review, makeContext().review)
    }

    func test_leavingConfirm_discardsThePendingPreview() async {
        let viewModel = PerpsTradeConfirmViewModel(context: makeContext(), format: .test)
        let started = expectation(description: "preview started")
        let finished = expectation(description: "cancelled preview finished")
        var continuation: CheckedContinuation<PerpsOpenOrderReview, Never>?
        viewModel.onEditAutoClose = {
            let editing = await viewModel.autoCloseEditingContext { _ in
                .success(await withCheckedContinuation {
                    continuation = $0
                    started.fulfill()
                })
            }
            XCTAssertNil(editing)
            finished.fulfill()
        }
        viewModel.editAutoClose()
        await fulfillment(of: [started], timeout: 1)
        viewModel.back()
        continuation?.resume(returning: makeContext(entryPrice: 120).review)
        await fulfillment(of: [finished], timeout: 1)

        let retried = expectation(description: "edit after returning")
        viewModel.onEditAutoClose = { retried.fulfill() }
        viewModel.editAutoClose()
        await fulfillment(of: [retried], timeout: 1)
    }

    private func makeContext(entryPrice: Double = 100) -> PerpsConfirmContext {
        PerpsConfirmContext(
            intent: PerpsOpenMarketIntent(
                marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01,
                autoClose: PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 101), stopLoss: nil)
            ),
            sizeDecimals: 6, priceDecimals: 2,
            review: PerpsOpenOrderReview(
                symbol: "BTC", marginUsd: 100, entryPrice: entryPrice, liquidationPrice: nil,
                notionalUsd: 1000, baseSize: 1000 / entryPrice,
                estimatedFeeUsd: nil, liquidationUnavailableReason: nil
            )
        )
    }
}
