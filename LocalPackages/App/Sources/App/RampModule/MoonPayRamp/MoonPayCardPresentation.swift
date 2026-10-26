import AppUI
import Foundation
import MoonPay
import TKLocalize

struct MoonPayCardPresentation {
    let title: String
    let brand: String
    let last4: String
    let subtitle: String
    let expiry: MoonPayPaymentMethodViewState.SubtitleSuffix?

    init(_ card: MoonPaySavedCard, now: Date = Date(), calendar: Calendar = .current) {
        let kind = card.cardType?.capitalized
        title = kind.map { TKLocales.Ramp.Moonpay.Card.titleKind($0) } ?? TKLocales.Ramp.Moonpay.Card.title
        brand = (card.brand ?? "card").capitalized
        last4 = card.last4 ?? "••••"
        let month = card.expirationMonth.flatMap { Int($0) }
        let year = card.expirationYear.flatMap { Int($0) }.map { $0 < 100 ? 2000 + $0 : $0 }
        let shortYear = year.map { String(format: "%02d", $0 % 100) }
        let shortMonth = month.map { String(format: "%02d", $0) }
        let date = [shortMonth, shortYear].compactMap { $0 }.joined(separator: "/")
        subtitle = "\(brand) •••• \(last4)"

        let isInactive = !(card.availability?.active ?? true)
        if let month, let year,
           let end = calendar.date(from: DateComponents(year: year, month: month + 1, day: 1))
        {
            if end <= now || isInactive {
                expiry = .init(text: TKLocales.Ramp.Moonpay.Card.expired(date), style: .error)
            } else if let soon = calendar.date(byAdding: .month, value: 3, to: now), end <= soon {
                expiry = .init(text: TKLocales.Ramp.Moonpay.Card.expires(date), style: .warning)
            } else {
                expiry = .init(text: TKLocales.Ramp.Moonpay.Card.expires(date), style: .neutral)
            }
        } else {
            expiry = isInactive ? .init(text: TKLocales.Ramp.Moonpay.Card.unavailable, style: .error) : nil
        }
    }
}
