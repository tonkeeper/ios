import Foundation

/// A position event from the wallet activity feed — the rows every perps history surface
/// shows, so the asset page, its full list and the wallet history agree on what happened.
public struct PerpsHistoryEvent: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case opened
        case increased
        /// A manual partial close; one by take profit, stop loss or liquidation takes that kind.
        case reduced
        case closed
        case liquidated
        case takeProfit
        case stopLoss
    }

    public struct TokenAmount: Equatable, Sendable {
        public let value: Double
        public let symbol: String

        public init(value: Double, symbol: String) {
            self.value = value
            self.symbol = symbol
        }
    }

    public let id: String
    public let kind: Kind
    public let marketId: Int64?
    public let symbol: String
    /// The side of the position, not the direction of the trade behind the event.
    public let side: PerpsTradeSide?
    public let date: Date
    public let leverage: Double?
    public let entryPrice: Double?
    public let closePrice: Double?
    public let baseSize: Double?
    public let usdSize: Double?
    /// Margin an opening or increasing event put up; what that event is worth.
    public let margin: Double?
    /// Realized result of a closing event, signed.
    public let pnl: Double?
    public let pnlPercent: Double?
    /// Funding accrued over the position's life, signed: positive is received.
    /// Full closes only — a partial close leaves it with the position.
    public let fundingUsd: Double?
    public let feeUsd: Double?
    public let fee: TokenAmount?

    public var isClosing: Bool {
        switch kind {
        case .opened, .increased: false
        case .reduced, .closed, .liquidated, .takeProfit, .stopLoss: true
        }
    }

    public init(
        id: String,
        kind: Kind,
        marketId: Int64?,
        symbol: String,
        side: PerpsTradeSide?,
        date: Date,
        leverage: Double? = nil,
        entryPrice: Double? = nil,
        closePrice: Double? = nil,
        baseSize: Double? = nil,
        usdSize: Double? = nil,
        margin: Double? = nil,
        pnl: Double? = nil,
        pnlPercent: Double? = nil,
        fundingUsd: Double? = nil,
        feeUsd: Double? = nil,
        fee: TokenAmount? = nil
    ) {
        self.id = id
        self.kind = kind
        self.marketId = marketId
        self.symbol = symbol
        self.side = side
        self.date = date
        self.leverage = leverage
        self.entryPrice = entryPrice
        self.closePrice = closePrice
        self.baseSize = baseSize
        self.usdSize = usdSize
        self.margin = margin
        self.pnl = pnl
        self.pnlPercent = pnlPercent
        self.fundingUsd = fundingUsd
        self.feeUsd = feeUsd
        self.fee = fee
    }
}
