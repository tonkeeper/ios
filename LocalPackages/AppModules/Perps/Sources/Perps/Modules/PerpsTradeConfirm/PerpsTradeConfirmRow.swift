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
        case wallet, totalAmount, toPerpsAccount, networkFee, activationFee, providerFee, temporaryReserve, minReceived
        case youWithdraw, arrivalTime, recipientAddress, provider
        case loyaltyReward
    }

    public let id: Kind
    public let title: String
    public let value: String
    public let valueParts: [PerpsTradeConfirmValuePart]?
    public let subValue: String?
    /// Under the whole row rather than the value: for text the value's column would wrap.
    public let note: String?
    public let tone: PerpsTradeConfirmTone
    public let showsChevron: Bool
    /// Shown on tap: what the value is made of.
    public let titleHint: String?
    /// A fee whose payment method can be switched: `feeMethod` follows the value with a switch,
    /// and a tap on the row picks another.
    public let showsFeePicker: Bool
    public let feeMethod: String?

    public init(
        id: Kind,
        title: String,
        value: String,
        valueParts: [PerpsTradeConfirmValuePart]? = nil,
        subValue: String?,
        note: String? = nil,
        tone: PerpsTradeConfirmTone = .neutral,
        showsChevron: Bool = false,
        titleHint: String? = nil,
        showsFeePicker: Bool = false,
        feeMethod: String? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.valueParts = valueParts
        self.subValue = subValue
        self.note = note
        self.tone = tone
        self.showsChevron = showsChevron
        self.titleHint = titleHint
        self.showsFeePicker = showsFeePicker
        self.feeMethod = feeMethod
    }
}
