import Foundation
import TKCore
import TKUIKit
import UIKit

final class SettingsListTooltipsConfigurator: SettingsListConfigurator {
    var didUpdateState: ((SettingsListState) -> Void)?
    var didSelectFirstLaunchDate: ((_ selectedDate: Date, _ completion: @escaping (Date) -> Void) -> Void)?

    var title: String {
        "Tooltips"
    }

    private let commonTooltipSettings: TooltipDataRepository
    private let tooltipOverrides: TooltipDataOverridesRepository
    private let withdrawTooltipSettings: WithdrawButtonTooltipRepository
    private let newHistoryEntryPointTooltipSettings: NewHistoryEntryPointTooltipRepository
    private let tradeTabTooltipSettings: TradeTabTooltipRepository
    private let favoriteTooltipSettings: FavoriteTooltipRepository
    private let addMultichainWalletTooltipSettings: AddMultichainWalletTooltipRepository
    private let calendar: Calendar
    private let dateFormatter: DateFormatter

    init(
        commonTooltipSettings: TooltipDataRepository,
        tooltipOverrides: TooltipDataOverridesRepository,
        withdrawTooltipSettings: WithdrawButtonTooltipRepository,
        newHistoryEntryPointTooltipSettings: NewHistoryEntryPointTooltipRepository,
        tradeTabTooltipSettings: TradeTabTooltipRepository,
        favoriteTooltipSettings: FavoriteTooltipRepository,
        addMultichainWalletTooltipSettings: AddMultichainWalletTooltipRepository,
        calendar: Calendar = .current
    ) {
        self.commonTooltipSettings = commonTooltipSettings
        self.tooltipOverrides = tooltipOverrides
        self.withdrawTooltipSettings = withdrawTooltipSettings
        self.newHistoryEntryPointTooltipSettings = newHistoryEntryPointTooltipSettings
        self.tradeTabTooltipSettings = tradeTabTooltipSettings
        self.favoriteTooltipSettings = favoriteTooltipSettings
        self.addMultichainWalletTooltipSettings = addMultichainWalletTooltipSettings
        self.calendar = calendar

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        self.dateFormatter = dateFormatter
    }

    func getInitialState() -> SettingsListState {
        createState()
    }

    private func createState() -> SettingsListState {
        var commonItems: [SettingsListItemsSectionItem] = [
            .listItem(createFirstLaunchDateItem()),
        ]
        if tooltipOverrides.firstLaunchDate != nil {
            commonItems.append(.listItem(createResetFirstLaunchDateOverrideItem()))
        }
        let withdrawButtonItems: [SettingsListItemsSectionItem] = [
            .listItem(createShownCountItem()),
            .listItem(createTargetActionPerformedItem()),
        ]
        let tradeTabItems: [SettingsListItemsSectionItem] = [
            .listItem(createTradeTabShownCountItem()),
            .listItem(createTradeTabTargetActionPerformedItem()),
        ]
        let newHistoryEntryPointItems: [SettingsListItemsSectionItem] = [
            .listItem(createNewHistoryEntryPointShownCountItem()),
            .listItem(createNewHistoryEntryPointTargetActionPerformedItem()),
        ]
        let favoriteItems: [SettingsListItemsSectionItem] = [
            .listItem(createFavoriteHasBeenShownItem()),
        ]
        let addMultichainWalletItems: [SettingsListItemsSectionItem] = [
            .listItem(createAddMultichainWalletShownCountItem()),
            .listItem(createAddMultichainWalletLastShownDateItem()),
        ]

        return SettingsListState(
            sections: [
                .items(
                    SettingsListItemsSection(
                        items: commonItems,
                        header: SettingsListSectionHeader(title: "Common")
                    )
                ),
                .items(
                    SettingsListItemsSection(
                        items: withdrawButtonItems,
                        header: SettingsListSectionHeader(title: "Withdraw Button")
                    )
                ),
                .items(
                    SettingsListItemsSection(
                        items: newHistoryEntryPointItems,
                        header: SettingsListSectionHeader(title: "History Entry Point")
                    )
                ),
                .items(
                    SettingsListItemsSection(
                        items: tradeTabItems,
                        header: SettingsListSectionHeader(title: "Trade Tab")
                    )
                ),
                .items(
                    SettingsListItemsSection(
                        items: favoriteItems,
                        header: SettingsListSectionHeader(title: "Favorite")
                    )
                ),
                .items(
                    SettingsListItemsSection(
                        items: addMultichainWalletItems,
                        header: SettingsListSectionHeader(title: "Add Multichain Wallet")
                    )
                ),
                .items(
                    SettingsListItemsSection(items: [
                        .button(createResetStateItem()),
                    ])
                ),
            ]
        )
    }

    private func createNewHistoryEntryPointShownCountItem() -> SettingsListItem {
        createValueItem(
            id: .newHistoryEntryPointTooltipShownCountItemIdentifier,
            title: "Shown count",
            value: String(newHistoryEntryPointTooltipSettings.shownCount)
        )
    }

    private func createNewHistoryEntryPointTargetActionPerformedItem() -> SettingsListItem {
        createValueItem(
            id: .newHistoryEntryPointTooltipTargetActionPerformedItemIdentifier,
            title: "Target action performed",
            value: newHistoryEntryPointTooltipSettings.isTargetActionPerformed ? "true" : "false"
        )
    }

    private func createFirstLaunchDateItem() -> SettingsListItem {
        let isOverriden = tooltipOverrides.firstLaunchDate != nil

        return SettingsListItem(
            id: .tooltipFirstLaunchDateItemIdentifier,
            title: SettingsListItemTitle("First launch date override"),
            captions: [
                SettingsListItemCaption("status: \(isOverriden ? "overridden" : "default")"),
                SettingsListItemCaption("value: \(formatted(commonTooltipSettings.firstLaunchDate))"),
            ],
            accessory: .text(
                SettingsListItemTextAccessory(
                    text: isOverriden ? "Update" : "Override"
                )
            ),
            onTap: { [weak self] _ in
                guard let self else { return }
                self.didSelectFirstLaunchDate?(
                    commonTooltipSettings.firstLaunchDate ?? Date()
                ) { [weak self] selectedDate in
                    self?.applyFirstLaunchDateOverride(selectedDate)
                }
            }
        )
    }

    private func createResetFirstLaunchDateOverrideItem() -> SettingsListItem {
        SettingsListItem(
            id: .tooltipResetFirstLaunchDateOverrideItemIdentifier,
            title: SettingsListItemTitle("Reset first launch date override"),
            captions: [SettingsListItemCaption("Use original app first launch date")],
            onTap: { [weak self] _ in
                self?.resetFirstLaunchDateOverride()
            }
        )
    }

    private func createTradeTabShownCountItem() -> SettingsListItem {
        createValueItem(
            id: .tradeTabTooltipShownCountItemIdentifier,
            title: "Shown count",
            value: String(tradeTabTooltipSettings.shownCount)
        )
    }

    private func createShownCountItem() -> SettingsListItem {
        createValueItem(
            id: .tooltipShownCountItemIdentifier,
            title: "Shown count",
            value: String(withdrawTooltipSettings.shownCount)
        )
    }

    private func createTargetActionPerformedItem() -> SettingsListItem {
        createValueItem(
            id: .tooltipTargetActionPerformedItemIdentifier,
            title: "Target action performed",
            value: withdrawTooltipSettings.isTargetActionPerformed ? "true" : "false"
        )
    }

    private func createFavoriteHasBeenShownItem() -> SettingsListItem {
        createValueItem(
            id: .favoriteTooltipHasBeenShownItemIdentifier,
            title: "Has been shown",
            value: favoriteTooltipSettings.hasBeenShown ? "true" : "false"
        )
    }

    private func createTradeTabTargetActionPerformedItem() -> SettingsListItem {
        createValueItem(
            id: .tradeTabTooltipTargetActionPerformedItemIdentifier,
            title: "Target action performed",
            value: tradeTabTooltipSettings.isTargetActionPerformed ? "true" : "false"
        )
    }

    private func createAddMultichainWalletShownCountItem() -> SettingsListItem {
        createValueItem(
            id: .addMultichainWalletTooltipShownCountItemIdentifier,
            title: "Shown count",
            value: String(addMultichainWalletTooltipSettings.shownCount)
        )
    }

    private func createAddMultichainWalletLastShownDateItem() -> SettingsListItem {
        createValueItem(
            id: .addMultichainWalletTooltipLastShownDateItemIdentifier,
            title: "Last shown date",
            value: formatted(addMultichainWalletTooltipSettings.lastShownDate)
        )
    }

    private func createResetStateItem() -> SettingsListButtonItem {
        SettingsListButtonItem(
            id: .tooltipResetStateItemIdentifier,
            title: "Reset tooltip state",
            appearance: .secondary,
            action: { [weak self] in
                guard let self else { return }
                self.withdrawTooltipSettings.resetPersistentState()
                self.newHistoryEntryPointTooltipSettings.resetPersistentState()
                self.tradeTabTooltipSettings.resetPersistentState()
                self.favoriteTooltipSettings.resetPersistentState()
                self.addMultichainWalletTooltipSettings.resetPersistentState()
                self.didUpdateState?(self.createState())
                ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Reset"))
            }
        )
    }

    private func createValueItem(id: String, title: String, value: String) -> SettingsListItem {
        SettingsListItem(
            id: id,
            title: SettingsListItemTitle(title),
            accessory: .text(SettingsListItemTextAccessory(text: value))
        )
    }

    private func applyFirstLaunchDateOverride(_ date: Date?) {
        guard let date else {
            return
        }
        tooltipOverrides.firstLaunchDate = calendar.startOfDay(for: date)
        didUpdateState?(createState())
        ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Override updated"))
    }

    private func resetFirstLaunchDateOverride() {
        tooltipOverrides.firstLaunchDate = nil
        didUpdateState?(createState())
        ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Override reset"))
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else {
            return "nil"
        }
        return dateFormatter.string(from: date)
    }
}

private extension String {
    static let tooltipFirstLaunchDateItemIdentifier = "tooltipFirstLaunchDateItemIdentifier"
    static let tooltipResetFirstLaunchDateOverrideItemIdentifier = "tooltipResetFirstLaunchDateOverrideItemIdentifier"
    static let tooltipShownCountItemIdentifier = "tooltipShownCountItemIdentifier"
    static let tooltipTargetActionPerformedItemIdentifier = "tooltipTargetActionPerformedItemIdentifier"
    static let newHistoryEntryPointTooltipShownCountItemIdentifier = "newHistoryEntryPointTooltipShownCountItemIdentifier"
    static let newHistoryEntryPointTooltipTargetActionPerformedItemIdentifier = "newHistoryEntryPointTooltipTargetActionPerformedItemIdentifier"
    static let tradeTabTooltipShownCountItemIdentifier = "tradeTabTooltipShownCountItemIdentifier"
    static let tradeTabTooltipTargetActionPerformedItemIdentifier = "tradeTabTooltipTargetActionPerformedItemIdentifier"
    static let favoriteTooltipHasBeenShownItemIdentifier = "favoriteTooltipHasBeenShownItemIdentifier"
    static let addMultichainWalletTooltipShownCountItemIdentifier = "addMultichainWalletTooltipShownCountItemIdentifier"
    static let addMultichainWalletTooltipLastShownDateItemIdentifier = "addMultichainWalletTooltipLastShownDateItemIdentifier"
    static let tooltipResetStateItemIdentifier = "tooltipResetStateItemIdentifier"
}
