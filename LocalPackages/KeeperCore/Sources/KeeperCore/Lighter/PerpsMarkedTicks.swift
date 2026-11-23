import Foundation
import PerpsModels

actor PerpsMarkedTicks {
    private let markPrices: @Sendable (Set<Int64>) -> AsyncStream<[Int64: Double]>
    private let emit: @Sendable (PerpsAccountTick) -> Void
    private var marks = [Int64: Double]()
    private var marketIds = Set<Int64>()
    private var follower: Task<Void, Never>?

    init(
        markPrices: @escaping @Sendable (Set<Int64>) -> AsyncStream<[Int64: Double]>,
        emit: @escaping @Sendable (PerpsAccountTick) -> Void
    ) {
        self.markPrices = markPrices
        self.emit = emit
    }

    deinit {
        follower?.cancel()
    }

    func follow(_ tick: PerpsAccountTick) {
        let ids = Set(tick.positions.map(\.marketId))
        marks = marks.filter { ids.contains($0.key) }
        if ids != marketIds {
            marketIds = ids
            follower?.cancel()
            follower = ids.isEmpty ? nil : Task { [weak self, markPrices] in
                for await prices in markPrices(ids) {
                    await self?.apply(prices)
                }
            }
        }
        emit(tick.marked(marks))
    }

    func stop() {
        follower?.cancel()
        follower = nil
        marketIds = []
    }

    private func apply(_ prices: [Int64: Double]) {
        guard follower != nil else { return }
        marks = prices.filter { marketIds.contains($0.key) }
        emit(.marks(marks))
    }
}

extension PerpsAccountTick {
    var positions: [PerpsPositionSummary] {
        switch self {
        case let .portfolio(snapshot): snapshot.positions
        case let .positions(positions, _): positions
        case .marks: []
        }
    }

    var requestedAt: TimeInterval? {
        switch self {
        case let .portfolio(snapshot): snapshot.requestedAt
        case let .positions(_, requestedAt): requestedAt
        case .marks: nil
        }
    }

    func followed(by next: PerpsAccountTick) -> PerpsAccountTick {
        switch (self, next) {
        case (.marks, _), (_, .portfolio), (_, .positions): next
        case let (_, .marks(marks)): marked(marks)
        }
    }

    func marked(_ marks: [Int64: Double]) -> PerpsAccountTick {
        let positions = positions.map { position in
            marks[position.marketId].map(position.marked(at:)) ?? position
        }
        switch self {
        case let .portfolio(snapshot):
            return .portfolio(PerpsAccountSnapshot(
                availableBalance: snapshot.availableBalance,
                collateral: snapshot.collateral,
                equity: snapshot.equity,
                transferableBalance: snapshot.transferableBalance,
                positions: positions,
                openOrders: snapshot.openOrders,
                requestedAt: snapshot.requestedAt
            ))
        case let .positions(_, requestedAt):
            return .positions(positions, requestedAt: requestedAt)
        case .marks:
            return self
        }
    }
}

extension PerpsPositionSummary {
    func marked(at mark: Double) -> PerpsPositionSummary {
        let pnl = PerpsTriggerROI.pnlUsd(side: side, entryPrice: entryPrice, baseAmount: baseSize, triggerPrice: mark)
        let roi = leverage
            .flatMap { PerpsTriggerROI.percent(side: side, entryPrice: entryPrice, leverage: $0, triggerPrice: mark) }
            .map(PerpsTriggerROI.cutToHundredths)
        return PerpsPositionSummary(
            positionId: positionId,
            marketId: marketId,
            symbol: symbol,
            side: side,
            baseSize: baseSize,
            notionalUsd: mark * baseSize,
            marginUsd: marginUsd,
            equityUsd: marginUsd + pnl,
            leverage: leverage,
            roiPercent: roi,
            entryPrice: entryPrice,
            liquidationPrice: liquidationPrice,
            unrealizedPnlUsd: pnl,
            realizedPnlUsd: realizedPnlUsd,
            fundingPaidUsd: fundingPaidUsd,
            liquidationDistancePercent: liquidationPrice > 0 ? (liquidationPrice - mark) / mark * 100 : nil,
            markPrice: mark
        )
    }
}
