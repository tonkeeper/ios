import AppUI
import Combine
import Foundation
import MoonPay
import TKLocalize
import TKUIKit

@MainActor
final class MoonPayPaymentMethodViewModel: ObservableObject {
    var onSelect: ((String) -> Void)?
    var onSelectP2P: (() -> Void)?
    var onSelectCard: ((String) -> Void)?
    var onRemoveCard: ((MoonPaySavedCard) -> Void)?
    var onCryptoDeposit: (() -> Void)?
    var onTapProvider: (() -> Void)?
    var onBack: (() -> Void)?
    var onClose: (() -> Void)?

    /// The name after "via"; no line under the title without it.
    @Published var providerName: String?
    /// Set once the providers are loaded and there is another one to pick.
    @Published var isProviderSwitchable = false
    /// The rows are another provider's while its methods load; taps on them are ignored.
    @Published var isLoading = false
    @Published private var selectedType: String?
    @Published private var selectedCardID: String?
    @Published private var savedCards: [MoonPaySavedCard]
    /// Cards whose removal is running; their menu is hidden so the removal is not sent twice.
    @Published private var removingCardIDs: Set<String> = []

    @Published private var rows: [RampPaymentMethodRow]
    private var canDeleteCards: Bool

    init(
        rows: [RampPaymentMethodRow],
        selectedType: String?,
        savedCards: [MoonPaySavedCard] = [],
        selectedCardID: String? = nil,
        canDeleteCards: Bool = false,
        removingCardIDs: Set<String> = []
    ) {
        self.rows = rows
        self.selectedType = selectedType
        self.savedCards = savedCards
        self.selectedCardID = selectedCardID
        self.canDeleteCards = canDeleteCards
        self.removingCardIDs = removingCardIDs
    }

    var screenState: MoonPayPaymentMethodViewState {
        MoonPayPaymentMethodViewState(
            title: TKLocales.Ramp.Deposit.PaymentMethod.title,
            provider: providerName.map {
                .init(caption: TKLocales.Ramp.Moonpay.PaymentMethod.via, name: $0, isSwitchable: isProviderSwitchable)
            },
            sections: savedSections + [
                .init(id: "cash", title: TKLocales.Ramp.Moonpay.PaymentMethod.cash, rows: cashRows),
            ],
            cryptoSection: .init(
                title: TKLocales.Ramp.Picker.cryptoTitle,
                content: {
                    var content = RampOnActionKind.receiveTokens.setupCellContent
                    content.title = TKLocales.Ramp.Moonpay.cryptoDeposit
                    return content
                }()
            ),
            isLoading: isLoading
        )
    }

    /// The methods of the provider picked meanwhile.
    func update(
        rows: [RampPaymentMethodRow],
        selectedType: String?,
        savedCards: [MoonPaySavedCard],
        selectedCardID: String?,
        canDeleteCards: Bool,
        removingCardIDs: Set<String>
    ) {
        self.rows = rows
        self.selectedType = selectedType
        self.savedCards = savedCards
        self.selectedCardID = selectedCardID
        self.canDeleteCards = canDeleteCards
        self.removingCardIDs = removingCardIDs
        isLoading = false
    }

    func cryptoDeposit() {
        onCryptoDeposit?()
    }

    /// Nothing to pick, such as after the provider's methods failed to load.
    var hasNoRows: Bool {
        rows.isEmpty && savedCards.isEmpty
    }

    func tapProvider() {
        onTapProvider?()
    }

    func select(_ id: String) {
        guard !isLoading else { return }
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

    func menuAction(rowID: String, itemID: String) {
        guard itemID == Self.removeItem,
              rowID.hasPrefix(Self.cardPrefix),
              let card = savedCards.first(where: { $0.id == rowID.dropFirst(Self.cardPrefix.count) }),
              removingCardIDs.insert(card.id).inserted
        else { return }
        onRemoveCard?(card)
    }

    func cardRemovalFailed(_ id: String) {
        removingCardIDs.remove(id)
    }

    /// The removed card's selection moves on as `MoonPayRampSource` does: to the first active saved
    /// card, or to a new card when none is left.
    func cardRemoved(_ id: String) {
        removingCardIDs.remove(id)
        savedCards.removeAll { $0.id == id }
        if selectedCardID == id {
            selectedCardID = savedCards.first { $0.availability?.active ?? false }?.id
        }
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
                subtitle: row.subtitle ?? "",
                iconURL: row.imageURL,
                badge: row.badge,
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
            trailing: selectedType == Self.cardType && selectedCardID == card.id ? .checkmark : .none,
            menu: removingCardIDs.contains(card.id) ? [] : cardMenu
        )
    }

    private var cardMenu: [MoonPayPaymentMethodViewState.MenuItem] {
        guard canDeleteCards else { return [] }
        return [.init(
            id: Self.removeItem,
            title: TKLocales.Ramp.Moonpay.Card.remove,
            icon: .TKUIKit.Icons.Size28.trashBin
        )]
    }

    private static let cardType = "card"
    private static let cardPrefix = "card:"
    private static let removeItem = "remove"
}
