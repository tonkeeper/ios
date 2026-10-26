import Foundation

public enum PerpsTradeConfirmTone: Equatable {
    case neutral, positive, negative, tertiary, accent
}

public struct PerpsTradeConfirmValuePart: Equatable {
    public let text: String
    public let tone: PerpsTradeConfirmTone

    public init(text: String, tone: PerpsTradeConfirmTone) {
        self.text = text
        self.tone = tone
    }
}

public struct PerpsTradeConfirmRow: Identifiable {
    public enum Kind: Hashable {
        case youPay, entry, leverage, liquidation, size, fee, autoClose
        case position, pnl, youReceive
        case youClose
        case wallet, totalAmount, networkFee, minReceived
        case youWithdraw, arrivalTime
    }

    public let id: Kind
    public let title: String
    public let value: String
    public let valueParts: [PerpsTradeConfirmValuePart]?
    public let subValue: String?
    public let tone: PerpsTradeConfirmTone
    public let showsChevron: Bool

    public init(
        id: Kind,
        title: String,
        value: String,
        valueParts: [PerpsTradeConfirmValuePart]? = nil,
        subValue: String?,
        tone: PerpsTradeConfirmTone = .neutral,
        showsChevron: Bool = false
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.valueParts = valueParts
        self.subValue = subValue
        self.tone = tone
        self.showsChevron = showsChevron
    }
}
