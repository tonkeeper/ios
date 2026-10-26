import Foundation
@testable import KeeperCore
import PerpsModels
import XCTest

final class PerpsHistoryEventMappingTests: XCTestCase {
    func test_closeReasonNamesTheEvent() {
        XCTAssertEqual(event(.perpsPositionOpened)?.kind, .opened)
        XCTAssertEqual(event(.perpsPositionClosed, reason: .manual)?.kind, .closed)
        XCTAssertEqual(event(.perpsPositionClosed, reason: nil)?.kind, .closed)
        XCTAssertEqual(event(.perpsPositionClosed, reason: .liquidation)?.kind, .liquidated)
        XCTAssertEqual(event(.perpsPositionClosed, reason: .takeProfit)?.kind, .takeProfit)
        XCTAssertEqual(event(.perpsPositionClosed, reason: .stopLoss)?.kind, .stopLoss)
    }

    func test_partialCloseIsReducedUnlessATriggerOrLiquidationClosedIt() {
        XCTAssertEqual(event(.perpsPositionIncreased)?.kind, .increased)
        XCTAssertEqual(event(.perpsPositionReduced, reason: .manual)?.kind, .reduced)
        XCTAssertEqual(event(.perpsPositionReduced, reason: nil)?.kind, .reduced)
        XCTAssertEqual(event(.perpsPositionReduced, reason: .liquidation)?.kind, .liquidated)
        XCTAssertEqual(event(.perpsPositionReduced, reason: .takeProfit)?.kind, .takeProfit)
        XCTAssertEqual(event(.perpsPositionReduced, reason: .stopLoss)?.kind, .stopLoss)
        XCTAssertEqual(event(.perpsPositionIncreased)?.isClosing, false)
        XCTAssertEqual(event(.perpsPositionReduced)?.isClosing, true)
    }

    func test_onlyPositionRowsAreEvents() {
        XCTAssertNil(event(.perpsBalanceDeposit))
        XCTAssertNil(event(.perpsBalanceWithdrawal))
        XCTAssertNil(event(.send))
    }

    /// A profit arrives as an incoming transfer and a loss leaves as an outgoing one.
    func test_closingResultIsSignedByTransferDirection() {
        XCTAssertEqual(event(.perpsPositionClosed, inAmountUsd: 0.0065)?.pnl, 0.0065)
        XCTAssertEqual(event(.perpsPositionClosed, outAmountUsd: 1.5702)?.pnl, -1.5702)
        XCTAssertNil(event(.perpsPositionClosed)?.pnl)
        XCTAssertNil(event(.perpsPositionOpened, inAmountUsd: 3)?.pnl)
        XCTAssertNil(event(.perpsPositionIncreased, inAmountUsd: 3)?.pnl)
        XCTAssertEqual(event(.perpsPositionReduced, outAmountUsd: 0.5)?.pnl, -0.5)
    }

    func test_marketSideAndFeeComeFromTheRow() throws {
        let mapped = try XCTUnwrap(event(
            .perpsPositionClosed,
            assetId: "lighter/mainnet/market/1",
            side: .short,
            feeAmount: "859160",
            feeAmountUsd: 0.8592
        ))
        XCTAssertEqual(mapped.marketId, 1)
        XCTAssertEqual(mapped.symbol, "BTC")
        XCTAssertEqual(mapped.side, .short)
        XCTAssertEqual(mapped.feeUsd, 0.8592)
        XCTAssertNil(mapped.fee, "a dollar fee is already shown by feeUsd")
    }

    func test_nonDollarFeeKeepsItsTokenAmount() throws {
        let eth = MultichainAssetDetails(assetId: "eth/mainnet/coin", name: "ETH", symbol: "ETH", decimals: 18, image: "")
        let mapped = try XCTUnwrap(event(.perpsPositionClosed, feeAmount: "1500000000000000", feeAmountUsd: 4.5, feeToken: eth))
        XCTAssertEqual(mapped.fee?.symbol, "ETH")
        XCTAssertEqual(try XCTUnwrap(mapped.fee?.value), 0.0015, accuracy: 1e-12)
    }

    func test_positionFiguresComeFromTheMeta() throws {
        let closed = try XCTUnwrap(event(.perpsPositionClosed, figures: MultichainActivityPerpsMeta(
            symbol: "SOL",
            assetId: "lighter/mainnet/market/2",
            side: .long,
            closeReason: .manual,
            accountIndex: 1,
            settledAt: nil,
            leverage: 2,
            entryPrice: 119.591,
            closePrice: 121.339,
            size: 0.085,
            sizeUsd: 10.313815,
            resultPercent: 2.858516,
            fundingUsd: -0.001169
        )))
        XCTAssertEqual(closed.leverage, 2)
        XCTAssertEqual(closed.entryPrice, 119.591)
        XCTAssertEqual(closed.closePrice, 121.339)
        XCTAssertEqual(closed.baseSize, 0.085)
        XCTAssertEqual(closed.usdSize, 10.313815)
        XCTAssertEqual(closed.pnlPercent, 2.858516)
        XCTAssertEqual(closed.fundingUsd, -0.001169)

        let opened = try XCTUnwrap(event(.perpsPositionOpened, figures: MultichainActivityPerpsMeta(
            symbol: "ETH",
            assetId: "lighter/mainnet/market/0",
            side: .long,
            closeReason: nil,
            accountIndex: 1,
            settledAt: nil,
            marginUsd: 0.992832
        )))
        XCTAssertEqual(opened.margin, 0.992832)
    }

    /// Funding stays with the position until it is closed in full.
    func test_fundingIsShownOnAFullCloseOnly() {
        let figures = MultichainActivityPerpsMeta(
            symbol: "SOL",
            assetId: "lighter/mainnet/market/2",
            side: .long,
            closeReason: .takeProfit,
            accountIndex: 1,
            settledAt: nil,
            fundingUsd: -0.001169
        )
        XCTAssertEqual(event(.perpsPositionClosed, figures: figures)?.fundingUsd, -0.001169)
        XCTAssertNil(event(.perpsPositionReduced, figures: figures)?.fundingUsd)
    }

    func test_idIsStableAcrossReloadsAndDistinctPerEvent() {
        let opened = event(.perpsPositionOpened, txIds: ["lighter:b", "lighter:a"])
        XCTAssertEqual(opened?.id, event(.perpsPositionOpened, txIds: ["lighter:a", "lighter:b"])?.id)
        XCTAssertNotEqual(opened?.id, event(.perpsPositionClosed, txIds: ["lighter:a", "lighter:b"])?.id)

        let firstWithoutTx = event(.perpsPositionOpened, txIds: [])
        XCTAssertEqual(firstWithoutTx?.id, event(.perpsPositionOpened, txIds: [])?.id)
        XCTAssertNotEqual(firstWithoutTx?.id, event(.perpsPositionOpened, txIds: [], blockTime: Date(timeIntervalSince1970: 1))?.id)
        XCTAssertNotEqual(firstWithoutTx?.id, event(.perpsPositionOpened, assetId: "lighter/mainnet/market/1", txIds: [])?.id)
    }

    private func event(
        _ type: MultichainActivityType,
        reason: MultichainPerpsCloseReason? = nil,
        assetId: String = "lighter/mainnet/market/0",
        side: MultichainPerpsSide = .long,
        inAmountUsd: Double? = nil,
        outAmountUsd: Double? = nil,
        feeAmount: String? = nil,
        feeAmountUsd: Double? = nil,
        feeToken: MultichainAssetDetails? = nil,
        txIds: [String] = ["lighter:0xabc"],
        blockTime: Date = Date(timeIntervalSince1970: 0),
        figures: MultichainActivityPerpsMeta? = nil
    ) -> PerpsHistoryEvent? {
        let usdc = MultichainAssetDetails(
            assetId: "lighter/mainnet/3",
            name: "USDC",
            symbol: "USDC",
            decimals: 6,
            image: ""
        )
        return PerpsHistoryEvent(activity: MultichainActivity(
            activityType: type,
            status: .confirmed,
            blockTime: blockTime,
            blockNumber: nil,
            fromChain: nil,
            toChain: nil,
            walletAddress: nil,
            direction: .selfTransfer,
            fromAddress: nil,
            toAddress: nil,
            outToken: outAmountUsd == nil ? nil : usdc,
            outAmount: nil,
            outAmountUsd: outAmountUsd,
            inToken: inAmountUsd == nil ? nil : usdc,
            inAmount: nil,
            inAmountUsd: inAmountUsd,
            feeToken: feeAmount == nil ? nil : feeToken ?? usdc,
            feeAmount: feeAmount,
            feeAmountUsd: feeAmountUsd,
            protocolName: nil,
            txIds: txIds,
            isRead: nil,
            perps: figures ?? MultichainActivityPerpsMeta(
                symbol: "BTC",
                assetId: assetId,
                side: side,
                closeReason: reason,
                accountIndex: 1,
                settledAt: nil
            )
        ))
    }
}
