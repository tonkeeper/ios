import AppUI
import Combine
import Foundation
import MoonPay
import TKLocalize

@MainActor
final class MoonPayPaymentMethodViewModel: ObservableObject {
    var onSelect: ((String) -> Void)?
    var onSelectP2P: (() -> Void)?
    var onSelectCard: ((String) -> Void)?
    var onCryptoDeposit: (() -> Void)?
    var onBack: (() -> Void)?
    var onClose: (() -> Void)?

    @Published private var selectedType: String?
    @Published private var selectedCardID: String?

    private let rows: [RampPaymentMethodRow]
    private let savedCards: [MoonPaySavedCard]

    init(
        rows: [RampPaymentMethodRow],
        selectedType: String?,
        savedCards: [MoonPaySavedCard] = [],
        selectedCardID: String? = nil
    ) {
        self.rows = rows
        self.selectedType = selectedType
        self.savedCards = savedCards
        self.selectedCardID = selectedCardID
    }

    var screenState: MoonPayPaymentMethodViewState {
        MoonPayPaymentMethodViewState(
            title: TKLocales.Ramp.Deposit.PaymentMethod.title,
            sections: savedSections + [
                .init(id: "cash", title: TKLocales.Ramp.Moonpay.PaymentMethod.cash, rows: cashRows),
            ],
            cryptoSection: .init(
                title: TKLocales.Ramp.Picker.cryptoTitle,
                content: RampOnActionKind.receiveTokens.setupCellContent
            )
        )
    }

    func cryptoDeposit() {
        onCryptoDeposit?()
    }

    func select(_ id: String) {
        if id.hasPrefix(Self.cardPrefix) {
            let cardID = String(id.dropFirst(Self.cardPrefix.count))
            guard savedCards.first(where: { $0.id == cardID })?.availability?.active ?? true else { return }
            selectedType = Self.cardType
            selectedCardID = cardID
            onSelectCard?(cardID)
            return
        }
        guard rows.first(where: { $0.type == id })?.isP2P != true else {
            onSelectP2P?()
            return
        }
        selectedType = id
        selectedCardID = nil
        onSelect?(id)
    }

    func back() {
        onBack?()
    }

    func close() {
        onClose?()
    }

    private var cashRows: [MoonPayPaymentMethodViewState.Row] {
        rows.map { row in
            .init(
                id: row.type,
                title: row.title,
                subtitle: row.subtitle,
                iconURL: row.imageURL,
                badge: nil,
                trailing: row.type == selectedType && (row.type != Self.cardType || selectedCardID == nil)
                    ? .checkmark
                    : .none
            )
        }
    }

    private var savedSections: [MoonPayPaymentMethodViewState.Section] {
        guard !savedCards.isEmpty else { return [] }
        return [.init(id: "saved", title: TKLocales.Ramp.Moonpay.PaymentMethod.saved, rows: savedCards.map(cardRow))]
    }

    private func cardRow(_ card: MoonPaySavedCard) -> MoonPayPaymentMethodViewState.Row {
        let presentation = MoonPayCardPresentation(card)
        return .init(
            id: Self.cardPrefix + card.id,
            title: presentation.title,
            subtitle: presentation.subtitle,
            iconURL: nil,
            savedCard: MoonPaySavedCardIcon(brand: presentation.brand, last4: presentation.last4),
            subtitleSuffix: presentation.expiry,
            isEnabled: card.availability?.active ?? true,
            trailing: selectedType == Self.cardType && selectedCardID == card.id ? .checkmark : .none
        )
    }

    private static let cardType = "card"
    private static let cardPrefix = "card:"
}
