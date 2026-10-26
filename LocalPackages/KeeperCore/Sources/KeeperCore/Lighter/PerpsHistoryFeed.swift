import Foundation
import PerpsModels

/// Perps history is read from the wallet activity feed, the one the wallet history shows,
/// not from the venue's own trade log: every surface then lists the same events.
struct PerpsHistoryFeed {
    let multichainService: MultichainService
    let wallet: Wallet

    func recent(marketId: Int64, limit: Int) async throws -> [PerpsHistoryEvent] {
        guard let state = wallet.multichainWalletState else { return [] }
        let page = try await multichainService.getWalletActivities(
            state: state,
            limit: limit,
            cursor: nil,
            chain: nil,
            assetId: nil,
            activityTypeFilter: .perps,
            showPerps: true,
            market: Int(marketId),
            hideDust: nil
        )
        return page.activities
            .compactMap(PerpsHistoryEvent.init(activity:))
            .filter { $0.marketId == marketId }
    }
}

public extension PerpsHistoryEvent {
    /// `nil` for anything that is not a position event: deposits, withdrawals, other chains.
    init?(activity: MultichainActivity) {
        let kind: Kind
        switch activity.activityType {
        case .perpsPositionOpened:
            kind = .opened
        case .perpsPositionIncreased:
            kind = .increased
        case .perpsPositionReduced, .perpsPositionClosed:
            switch activity.perps?.closeReason {
            case .liquidation: kind = .liquidated
            case .takeProfit: kind = .takeProfit
            case .stopLoss: kind = .stopLoss
            case .manual, nil: kind = activity.activityType == .perpsPositionClosed ? .closed : .reduced
            }
        default:
            return nil
        }
        let perps = activity.perps
        self.init(
            id: Self.eventID(activity),
            kind: kind,
            marketId: perps?.assetId.flatMap(PerpsMarketAssetID.marketId(assetId:)),
            symbol: perps?.symbol ?? "",
            side: perps?.side.map { $0 == .long ? .long : .short },
            date: activity.blockTime,
            leverage: perps?.leverage,
            entryPrice: perps?.entryPrice,
            closePrice: perps?.closePrice,
            baseSize: perps?.size,
            usdSize: perps?.sizeUsd,
            margin: perps?.marginUsd,
            pnl: kind == .opened || kind == .increased ? nil : Self.result(activity),
            pnlPercent: perps?.resultPercent,
            fundingUsd: activity.activityType == .perpsPositionClosed ? perps?.fundingUsd : nil,
            feeUsd: activity.feeAmountUsd,
            fee: Self.fee(activity)
        )
    }
}

private extension PerpsHistoryEvent {
    static func eventID(_ activity: MultichainActivity) -> String {
        let perps = activity.perps
        var components = [activity.activityType.rawValue, String(activity.blockTime.timeIntervalSince1970)]
        components.append(activity.blockNumber.map { "\($0)" } ?? "")
        components.append(perps?.assetId ?? "")
        components.append(perps?.accountIndex.map { "\($0)" } ?? "")
        components.append(perps?.side?.rawValue ?? "")
        components.append(perps?.size.map { "\($0)" } ?? "")
        components.append(perps?.entryPrice.map { "\($0)" } ?? "")
        components.append(perps?.closePrice.map { "\($0)" } ?? "")
        components.append(perps?.marginUsd.map { "\($0)" } ?? "")
        components.append(activity.inAmount ?? "")
        components.append(activity.outAmount ?? "")
        components += activity.txIds.sorted()
        return components.map { "\($0.utf8.count):\($0)" }.joined()
    }

    /// A closing event books its result as a transfer: a profit comes in, a loss goes out.
    static func result(_ activity: MultichainActivity) -> Double? {
        switch (activity.inAmountUsd, activity.outAmountUsd) {
        case (nil, nil): nil
        case let (income, outcome): (income ?? 0) - (outcome ?? 0)
        }
    }

    /// `nil` for a dollar fee: `feeUsd` already shows it.
    static func fee(_ activity: MultichainActivity) -> TokenAmount? {
        guard let amount = activity.feeAmount, let token = activity.feeToken, !activity.isPerpsDollar(token),
              let units = Decimal(string: amount) else { return nil }
        let value = units / pow(Decimal(10), token.decimals)
        return TokenAmount(value: NSDecimalNumber(decimal: value).doubleValue, symbol: activity.displaySymbol(for: token))
    }
}
