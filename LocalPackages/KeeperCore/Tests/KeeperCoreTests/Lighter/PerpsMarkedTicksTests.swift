import Foundation
@testable import KeeperCore
import PerpsModels
import XCTest

final class PerpsMarkedTicksTests: XCTestCase {
    func testAMarkRepricesALongAndAShort() throws {
        let long = position(marketId: 1, side: .long, size: 2, entry: 100, leverage: 10, margin: 20, liquidation: 91).marked(at: 110)
        let short = position(marketId: 2, side: .short, size: 1, entry: 100, leverage: 5, margin: 20, liquidation: 119).marked(at: 90)

        XCTAssertEqual(long.unrealizedPnlUsd, 20, accuracy: 1e-9)
        XCTAssertEqual(long.notionalUsd, 220, accuracy: 1e-9)
        XCTAssertEqual(long.equityUsd, 40, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(long.roiPercent), 100, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(long.liquidationDistancePercent), (91 - 110) / 110 * 100, accuracy: 1e-9)
        XCTAssertEqual(long.markPrice, 110)
        XCTAssertEqual(long.marginUsd, 20)
        XCTAssertEqual(long.liquidationPrice, 91)
        XCTAssertEqual(short.unrealizedPnlUsd, 10, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(short.roiPercent), 50, accuracy: 1e-9)
    }

    func testRoiIsCutTowardZeroAndEmptyWithoutLeverage() throws {
        let gain = position(marketId: 1, side: .long, size: 1, entry: 100, leverage: 1, margin: 100, liquidation: 0).marked(at: 112.34567)
        let loss = position(marketId: 1, side: .long, size: 1, entry: 100, leverage: 1, margin: 100, liquidation: 0).marked(at: 87.65433)
        let unleveraged = position(marketId: 1, side: .long, size: 1, entry: 100, leverage: nil, margin: 100, liquidation: 0).marked(at: 110)
        let binaryShortfall = position(marketId: 1, side: .long, size: 1, entry: 100, leverage: 1, margin: 100, liquidation: 0).marked(at: 101.1)

        XCTAssertEqual(try XCTUnwrap(gain.roiPercent), 12.34, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(loss.roiPercent), -12.34, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(binaryShortfall.roiPercent), 1.1, accuracy: 1e-9)
        XCTAssertNil(unleveraged.roiPercent)
        XCTAssertNil(gain.liquidationDistancePercent)
    }

    func testAMarketWithoutAMarkKeepsItsReadValues() {
        let read = position(marketId: 1, side: .long, size: 1, entry: 100, leverage: 2, margin: 50, liquidation: 60)
        let other = position(marketId: 2, side: .long, size: 1, entry: 100, leverage: 2, margin: 50, liquidation: 60)

        let marked = PerpsAccountTick.positions([read, other]).marked([2: 120]).positions

        XCTAssertEqual(marked.first, read)
        XCTAssertEqual(marked.last?.unrealizedPnlUsd, 20)
    }

    func testAPriceUpdateSendsOnlyTheMarksAndAReReadKeepsTheLastMark() async {
        let prices = PriceSource()
        let emitted = TickRecorder()
        let marked = PerpsMarkedTicks(markPrices: { prices.stream(for: $0) }, emit: { emitted.append($0) })
        let first = PerpsAccountTick.positions([
            position(marketId: 1, side: .long, size: 1, entry: 100, leverage: 2, margin: 50, liquidation: 60),
        ])

        await marked.follow(first)
        await prices.waitForStream()
        prices.send([1: 110, 2: 90])
        await emitted.wait(count: 2)
        await marked.follow(first)
        await emitted.wait(count: 3)

        XCTAssertEqual(emitted.ticks.map { $0.positions.first?.unrealizedPnlUsd }, [0, nil, 10])
        guard case let .marks(marks) = emitted.ticks[1] else { return XCTFail("a price update must send only the marks") }
        XCTAssertEqual(marks, [1: 110])
        XCTAssertEqual(prices.openedMarkets, [[1]])
        await marked.stop()
    }

    func testMarksRepriceAPendingReadAndANewerReadReplacesPendingMarks() {
        let read = PerpsAccountTick.positions([
            position(marketId: 1, side: .long, size: 1, entry: 100, leverage: 2, margin: 50, liquidation: 60),
        ], requestedAt: 5)
        let newer = PerpsAccountTick.positions([], requestedAt: 6)

        let repriced = read.followed(by: .marks([1: 110]))

        XCTAssertEqual(repriced.positions.first?.unrealizedPnlUsd, 10)
        XCTAssertEqual(repriced.requestedAt, 5)
        XCTAssertEqual(PerpsAccountTick.marks([1: 110]).followed(by: newer).requestedAt, 6)
        guard case let .marks(marks) = PerpsAccountTick.marks([1: 110]).followed(by: .marks([1: 120])) else {
            return XCTFail("newer marks must replace pending ones")
        }
        XCTAssertEqual(marks, [1: 120])
    }
}

private extension PerpsMarkedTicksTests {
    func position(
        marketId: Int64,
        side: PerpsTradeSide,
        size: Double,
        entry: Double,
        leverage: Double?,
        margin: Double,
        liquidation: Double
    ) -> PerpsPositionSummary {
        PerpsPositionSummary(
            positionId: "lighter:\(marketId)",
            marketId: marketId,
            symbol: "M\(marketId)",
            side: side,
            baseSize: size,
            notionalUsd: size * entry,
            marginUsd: margin,
            equityUsd: margin,
            leverage: leverage,
            roiPercent: 0,
            entryPrice: entry,
            liquidationPrice: liquidation,
            unrealizedPnlUsd: 0,
            realizedPnlUsd: 0,
            fundingPaidUsd: nil,
            liquidationDistancePercent: nil,
            markPrice: entry
        )
    }
}

private final class PriceSource: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations = [AsyncStream<[Int64: Double]>.Continuation]()
    private var opened = [Set<Int64>]()

    var openedMarkets: [Set<Int64>] {
        lock.withLock { opened }
    }

    func stream(for marketIds: Set<Int64>) -> AsyncStream<[Int64: Double]> {
        let (stream, continuation) = AsyncStream<[Int64: Double]>.makeStream()
        lock.withLock {
            continuations.append(continuation)
            opened.append(marketIds)
        }
        return stream
    }

    func waitForStream() async {
        for _ in 0 ..< 100 where lock.withLock({ continuations.isEmpty }) {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func send(_ prices: [Int64: Double]) {
        lock.withLock { continuations }.forEach { $0.yield(prices) }
    }
}

private final class TickRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded = [PerpsAccountTick]()

    var ticks: [PerpsAccountTick] {
        lock.withLock { recorded }
    }

    func append(_ tick: PerpsAccountTick) {
        lock.withLock { recorded.append(tick) }
    }

    func wait(count: Int) async {
        for _ in 0 ..< 100 where ticks.count < count {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
