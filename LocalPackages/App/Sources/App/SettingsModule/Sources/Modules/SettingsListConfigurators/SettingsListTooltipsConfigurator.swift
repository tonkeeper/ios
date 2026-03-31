import Foundation
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
    private let calendar: Calendar
    private let dateFormatter: DateFormatter

    init(
        commonTooltipSettings: TooltipDataRepository,
        tooltipOverrides: TooltipDataOverridesRepository,
        withdrawTooltipSettings: WithdrawButtonTooltipRepository,
        calendar: Calendar = .current
    ) {
        self.commonTooltipSettings = commonTooltipSettings
        self.tooltipOverrides = tooltipOverrides
        self.withdrawTooltipSettings = withdrawTooltipSettings
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
            .listItem(createInstructionUnderstoodItem()),
        ]

        return SettingsListState(
            sections: [
                .listItems(
                    SettingsListItemsSection(
                        items: commonItems,
                        headerConfiguration: SettingsListSectionHeaderView.Configuration(title: "Common")
                    )
                ),
                .listItems(
                    SettingsListItemsSection(
                        items: withdrawButtonItems,
                        headerConfiguration: SettingsListSectionHeaderView.Configuration(title: "Withdraw Button")
                    )
                ),
                .listItems(
                    SettingsListItemsSection(items: [
                        .button(createResetStateItem()),
                    ])
                ),
            ]
        )
    }

    private func createFirstLaunchDateItem() -> SettingsListItem {
        let isOverriden = tooltipOverrides.firstLaunchDate != nil

        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: "First launch date override"),
                    captionViewsConfigurations: [
                        TKListItemTextView.Configuration(
                            text: "status: \(isOverriden ? "overridden" : "default")",
                            color: .Text.secondary,
                            textStyle: .body2
                        ),
                        TKListItemTextView.Configuration(
                            text: "value: \(formatted(commonTooltipSettings.firstLaunchDate))",
                            color: .Text.secondary,
                            textStyle: .body2
                        ),
                    ]
                )
            )
        )

        return SettingsListItem(
            id: .tooltipFirstLaunchDateItemIdentifier,
            cellConfiguration: cellConfiguration,
            accessory: .text(
                TKListItemTextAccessoryView.Configuration(
                    text: isOverriden ? "Update" : "Override",
                    color: .Text.primary,
                    textStyle: .body2
                )
            ),
            onSelection: { [weak self] _ in
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
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: "Reset first launch date override"),
                    captionViewsConfigurations: [
                        TKListItemTextView.Configuration(
                            text: "Use original app first launch date",
                            color: .Text.secondary,
                            textStyle: .body2
                        ),
                    ]
                )
            )
        )

        return SettingsListItem(
            id: .tooltipResetFirstLaunchDateOverrideItemIdentifier,
            cellConfiguration: cellConfiguration,
            accessory: .none,
            onSelection: { [weak self] _ in
                self?.resetFirstLaunchDateOverride()
            }
        )
    }

    private func createShownCountItem() -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: "Shown count")
                )
            )
        )

        return SettingsListItem(
            id: .tooltipShownCountItemIdentifier,
            cellConfiguration: cellConfiguration,
            accessory: .text(
                TKListItemTextAccessoryView.Configuration(
                    text: String(withdrawTooltipSettings.shownCount),
                    color: .Text.primary,
                    textStyle: .body2
                )
            ),
            onSelection: nil
        )
    }

    private func createInstructionUnderstoodItem() -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: "Instruction understood")
                )
            )
        )

        return SettingsListItem(
            id: .tooltipInstructionUnderstoodItemIdentifier,
            cellConfiguration: cellConfiguration,
            accessory: .text(
                TKListItemTextAccessoryView.Configuration(
                    text: withdrawTooltipSettings.isInstructionUnderstood ? "true" : "false",
                    color: .Text.primary,
                    textStyle: .body2
                )
            ),
            onSelection: nil
        )
    }

    private func createResetStateItem() -> SettingsButtonListItem {
        var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString("Reset tooltip state"))
        buttonConfiguration.action = { [weak self] in
            guard let self else { return }
            self.withdrawTooltipSettings.resetPersistentState()
            self.didUpdateState?(self.createState())
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Reset"))
        }

        return SettingsButtonListItem(
            id: .tooltipResetStateItemIdentifier,
            cellConfiguration: TKButtonCollectionViewCell.Configuration(buttonConfiguration: buttonConfiguration)
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
    static let tooltipInstructionUnderstoodItemIdentifier = "tooltipInstructionUnderstoodItemIdentifier"
    static let tooltipResetStateItemIdentifier = "tooltipResetStateItemIdentifier"
}
