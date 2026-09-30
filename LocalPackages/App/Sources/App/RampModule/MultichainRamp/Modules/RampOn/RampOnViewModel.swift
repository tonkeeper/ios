import Foundation
import KeeperCore
import SwiftUI
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

@MainActor
final class RampOnViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded
        case failed
    }

    let flow: RampFlow

    var onClose: (() -> Void)?
    var onTapReceiveTokens: (() -> Void)?
    var onTapLayoutCard: ((OnRampLayoutCard) -> Void)?

    @Published private(set) var state: State = .loading
    @Published private(set) var layoutCards: OnRampLayoutCards?

    private let multichainRampService: MultichainRampService
    private let currencyStore: CurrencyStore

    init(
        flow: RampFlow,
        multichainRampService: MultichainRampService,
        currencyStore: CurrencyStore
    ) {
        self.flow = flow
        self.multichainRampService = multichainRampService
        self.currencyStore = currencyStore
    }

    var screenTitle: String {
        flow.title
    }

    var actionItem: RampOnListItem {
        .action(.receiveTokens)
    }

    var layoutItems: [RampOnListItem] {
        guard state == .loaded, let layoutCards else {
            return []
        }

        return layoutCards.items.map { .card($0) }
    }

    var showsLayoutError: Bool {
        state == .failed
    }

    var isLayoutLoading: Bool {
        state == .loading
    }

    func viewDidLoad() {
        Task {
            await loadLayoutCards()
        }
    }

    func close() {
        onClose?()
    }

    func select(item: RampOnListItem) {
        switch item {
        case .action(.receiveTokens):
            onTapReceiveTokens?()
        case let .card(card):
            onTapLayoutCard?(card)
        }
    }

    func retry() {
        Task {
            await loadLayoutCards()
        }
    }
}

private extension RampOnViewModel {
    func loadLayoutCards() async {
        state = .loading
        layoutCards = nil

        let currency = currencyStore.state.code
        do {
            let cards = try await multichainRampService.getLayoutCards(
                flow: flow.api,
                currency: currency
            )
            layoutCards = cards
            state = .loaded
            Log.multichainRamp.i(
                "layout cards loaded",
                extraInfo: ["flow": flow.api, "currency": currency, "cards": "\(cards.items.count)"]
            )
        } catch {
            layoutCards = nil
            state = .failed
            Log.multichainRamp.failure(
                "layout cards loading failed",
                error: error,
                extraInfo: ["flow": flow.api, "currency": currency]
            )
        }
    }
}

enum RampOnListItem: Identifiable, Equatable {
    case action(RampOnActionKind)
    case card(OnRampLayoutCard)

    var id: String {
        switch self {
        case let .action(kind):
            return "action-\(kind.rawValue)"
        case let .card(card):
            return "card-\(card.title)-\(card.image)"
        }
    }
}

enum RampOnActionKind: String, Equatable {
    case receiveTokens
}

extension RampOnActionKind {
    var setupCellContent: SetupCellContent {
        SetupCellContent(
            icon: .init(
                image: .TKUIKit.Icons.Size28.qrCode,
                tintColor: .accentBlue,
                backgroundColor: .accentBlue.opacity(0.16)
            ),
            title: TKLocales.Ramp.Deposit.receiveTokens,
            titleTextStyle: .label1,
            subtitle: .init(text: TKLocales.Ramp.Deposit.receiveTokensSubtitle),
            accessory: .chevron
        )
    }
}
