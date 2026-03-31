public extension TKLocales.Settings.Purchases.Token {
    static func tokenCount(count: Int) -> String {
        switch plural(count: count) {
        case .few: return TokenCount.few
        case .many: return TokenCount.many
        case .one: return TokenCount.one
        case .other: return TokenCount.other
        case .zero: return TokenCount.zero
        }
    }
}

public extension TKLocales.Battery.Refill {
    static func chargesCount(count: Int) -> String {
        switch plural(count: count) {
        case .few: return Charges.few
        case .many: return Charges.many
        case .one: return Charges.one
        case .other: return Charges.other
        case .zero: return Charges.zero
        }
    }

    static func refunded(count: Int) -> String {
        switch plural(count: count) {
        case .few: return Refunded.few
        case .many: return Refunded.many
        case .one: return Refunded.one
        case .other: return Refunded.other
        case .zero: return Refunded.zero
        }
    }
}

public extension TKLocales.SubscriptionPluginWarning {
    static func titlePluralized(count: Int) -> (String) {
        switch plural(count: count) {
        case .few: return Title.few(count)
        case .many: return Title.many(count)
        case .one: return Title.one(count)
        case .other: return Title.other(count)
        case .zero: return Title.zero(count)
        }
    }
}
