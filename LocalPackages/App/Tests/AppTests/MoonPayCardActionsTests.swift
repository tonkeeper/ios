@testable import App
import AppUI
import MoonPay
import XCTest

@MainActor
final class MoonPayCardActionsTests: XCTestCase {
    func test_cardRows_offerRemoveOnlyWhenDeletionIsAllowed() {
        let card = MoonPaySavedCard(id: "pm_1", brand: "visa", last4: "4148")

        let deletable = MoonPayPaymentMethodViewModel(rows: [], selectedType: nil, savedCards: [card], canDeleteCards: true)
        XCTAssertEqual(savedRows(deletable).first?.menu.map(\.id), ["remove"])

        let fixed = MoonPayPaymentMethodViewModel(rows: [], selectedType: nil, savedCards: [card], canDeleteCards: false)
        XCTAssertEqual(savedRows(fixed).first?.menu.map(\.id), [])
    }

    func test_menuAction_reportsTheCardAndRemovalDropsIt() {
        let first = MoonPaySavedCard(id: "pm_1", brand: "visa", last4: "4148", availability: .init(active: true))
        let second = MoonPaySavedCard(id: "pm_2", brand: "mastercard", last4: "4771", availability: .init(active: true))
        let viewModel = MoonPayPaymentMethodViewModel(
            rows: [cardMethod],
            selectedType: "card",
            savedCards: [first, second],
            selectedCardID: "pm_1",
            canDeleteCards: true
        )
        var removed: [String] = []
        viewModel.onRemoveCard = { removed.append($0.id) }

        viewModel.menuAction(rowID: "card:pm_1", itemID: "remove")
        viewModel.menuAction(rowID: "card:pm_1", itemID: "rename")
        viewModel.menuAction(rowID: "apple_pay", itemID: "remove")
        XCTAssertEqual(removed, ["pm_1"])

        viewModel.cardRemoved("pm_1")
        XCTAssertEqual(savedRows(viewModel).map(\.id), ["card:pm_2"])
        XCTAssertEqual(savedRows(viewModel).map(\.trailing), [.checkmark])

        viewModel.cardRemoved("pm_2")
        XCTAssertNil(viewModel.screenState.sections.first { $0.id == "saved" })
        XCTAssertEqual(cardRow(viewModel)?.trailing, .checkmark)
    }

    func test_removingTheSelectedCard_movesTheCheckmarkToTheFirstActiveCard() {
        let selected = MoonPaySavedCard(id: "pm_1", availability: .init(active: true))
        let expired = MoonPaySavedCard(id: "pm_2", availability: .init(active: false))
        let active = MoonPaySavedCard(id: "pm_3", availability: .init(active: true))
        let viewModel = MoonPayPaymentMethodViewModel(
            rows: [cardMethod],
            selectedType: "card",
            savedCards: [selected, expired, active],
            selectedCardID: "pm_1",
            canDeleteCards: true
        )

        viewModel.cardRemoved("pm_1")

        XCTAssertEqual(savedRows(viewModel).map(\.trailing), [.none, .checkmark])
        XCTAssertEqual(cardRow(viewModel)?.trailing, MoonPayPaymentMethodViewState.Trailing.none)

        viewModel.cardRemoved("pm_3")

        XCTAssertEqual(savedRows(viewModel).map(\.trailing), [.none])
        XCTAssertEqual(cardRow(viewModel)?.trailing, .checkmark)
    }

    func test_menuAction_ignoresARepeatWhileTheRemovalRuns() {
        let card = MoonPaySavedCard(id: "pm_1", availability: .init(active: true))
        let other = MoonPaySavedCard(id: "pm_2", availability: .init(active: true))
        let viewModel = MoonPayPaymentMethodViewModel(rows: [], selectedType: nil, savedCards: [card, other], canDeleteCards: true)
        var removed: [String] = []
        viewModel.onRemoveCard = { removed.append($0.id) }

        viewModel.menuAction(rowID: "card:pm_1", itemID: "remove")
        viewModel.menuAction(rowID: "card:pm_1", itemID: "remove")

        XCTAssertEqual(removed, ["pm_1"])
        XCTAssertEqual(savedRows(viewModel).map(\.menu.isEmpty), [true, false])

        viewModel.cardRemovalFailed("pm_1")
        XCTAssertEqual(savedRows(viewModel).map(\.menu.isEmpty), [false, false])
        viewModel.menuAction(rowID: "card:pm_1", itemID: "remove")
        XCTAssertEqual(removed, ["pm_1", "pm_1"])
    }

    func test_aReopenedScreen_hidesTheMenuOfACardStillBeingRemoved() {
        let card = MoonPaySavedCard(id: "pm_1", availability: .init(active: true))
        let viewModel = MoonPayPaymentMethodViewModel(
            rows: [],
            selectedType: nil,
            savedCards: [card],
            canDeleteCards: true,
            removingCardIDs: ["pm_1"]
        )
        var removed: [String] = []
        viewModel.onRemoveCard = { removed.append($0.id) }

        viewModel.menuAction(rowID: "card:pm_1", itemID: "remove")

        XCTAssertEqual(removed, [])
        XCTAssertEqual(savedRows(viewModel).first?.menu.isEmpty, true)
        viewModel.cardRemoved("pm_1")
        XCTAssertTrue(savedRows(viewModel).isEmpty)
    }

    private let cardMethod = RampPaymentMethodRow(type: "card", title: "Card", image: "", isP2P: false)

    private func cardRow(_ viewModel: MoonPayPaymentMethodViewModel) -> MoonPayPaymentMethodViewState.Row? {
        viewModel.screenState.sections.first { $0.id == "cash" }?.rows.first { $0.id == "card" }
    }

    private func savedRows(_ viewModel: MoonPayPaymentMethodViewModel) -> [MoonPayPaymentMethodViewState.Row] {
        viewModel.screenState.sections.first { $0.id == "saved" }?.rows ?? []
    }
}
