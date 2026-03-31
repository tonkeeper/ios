import KeeperCore
import TKFeatureFlags
import TKUIKit
import UIKit

private extension UIView {
    var firstButtonWithMenu: UIButton? {
        if let button = self as? UIButton, button.menu != nil, !button.isHidden, button.isEnabled {
            return button
        }
        for subview in subviews {
            guard let button = subview.firstButtonWithMenu else {
                continue
            }
            return button
        }
        return nil
    }
}

final class SettingsListFeatureFlagsConfigurator: SettingsListConfigurator {
    var didUpdateState: ((SettingsListState) -> Void)?

    var title: String {
        "Feature Flags"
    }

    private let featureFlags: TKFeatureFlags
    private let configurationAssembly: ConfigurationAssembly

    init(
        featureFlags: TKFeatureFlags,
        configurationAssembly: ConfigurationAssembly
    ) {
        self.featureFlags = featureFlags
        self.configurationAssembly = configurationAssembly
    }

    func getInitialState() -> SettingsListState {
        createState()
    }

    private func createState() -> SettingsListState {
        let sortedFlags = FeatureFlag.allCases
            .sorted(by: { $0.localKey < $1.localKey })
        let enabledFlags = sortedFlags.filter { !configurationAssembly.configuration.isFeatureFlagDisabledByRemoteConfig($0) }
        let disabledFlags = sortedFlags.filter { configurationAssembly.configuration.isFeatureFlagDisabledByRemoteConfig($0) }

        let sections: [SettingsListSection] = [
            .listItems(
                SettingsListItemsSection(
                    items: enabledFlags.compactMap(createFlagItem).map(SettingsListItemsSectionItem.listItem),
                    headerConfiguration: SettingsListSectionHeaderView.Configuration(title: "Allowed by keys/all")
                )
            ),
            .listItems(
                SettingsListItemsSection(
                    items: disabledFlags.compactMap(createFlagItem).map(SettingsListItemsSectionItem.listItem),
                    headerConfiguration: SettingsListSectionHeaderView.Configuration(title: "Disabled by keys/all")
                )
            ),
        ]

        return SettingsListState(
            sections: sections
        )
    }

    private func createFlagItem(_ flag: FeatureFlag) -> SettingsListItem? {
        let valuesByFlag = featureFlags.allValues
        guard let value = valuesByFlag[flag] else {
            return nil
        }
        let isDisabledByRemoteConfig = configurationAssembly.configuration.isFeatureFlagDisabledByRemoteConfig(flag)
        let localValue = value.localValue
        let remoteValue = value.remoteValue
        let defaultValue = value.defaultValue
        let resolvedValue = value.resolvedValue

        let titleColor: UIColor = isDisabledByRemoteConfig ? .Text.tertiary : .Text.primary
        let detailsColor: UIColor = isDisabledByRemoteConfig ? .Text.tertiary : .Text.secondary
        let localValueColor: UIColor = isDisabledByRemoteConfig ? .Text.tertiary : .Text.primary

        let applyOverride: (Bool?) -> Void = { [weak self] overrideValue in
            guard let self else { return }
            if let overrideValue {
                self.featureFlags[flag] = overrideValue
            } else {
                self.featureFlags.resetValue(for: flag)
            }
            self.didUpdateState?(self.createState())
        }

        let menu = UIMenu(children: [
            UIAction(
                title: "default",
                state: localValue == nil ? .on : .off,
                handler: { _ in
                    applyOverride(nil)
                }
            ),
            UIAction(
                title: "force true",
                state: localValue == true ? .on : .off,
                handler: { _ in
                    applyOverride(true)
                }
            ),
            UIAction(
                title: "force false",
                state: localValue == false ? .on : .off,
                handler: { _ in
                    applyOverride(false)
                }
            ),
        ])

        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(
                        title: flag.localKey.withTextStyle(.label1, color: titleColor, alignment: .left),
                        numberOfLines: 1
                    ),
                    captionViewsConfigurations: [
                        TKListItemTextView.Configuration(
                            text: "remote: \(remoteValue.displayText)",
                            color: detailsColor,
                            textStyle: .body2
                        ),
                        TKListItemTextView.Configuration(
                            text: "local: \(localValue.displayText)",
                            color: detailsColor,
                            textStyle: .body2
                        ),
                        TKListItemTextView.Configuration(
                            text: "default: \(defaultValue.displayText)",
                            color: detailsColor,
                            textStyle: .body2
                        ),
                    ]
                )
            )
        )

        if isDisabledByRemoteConfig {
            return SettingsListItem(
                id: "featureFlag_\(flag.localKey)",
                cellConfiguration: cellConfiguration,
                accessory: .text(
                    TKListItemTextAccessoryView.Configuration(
                        text: "resolved: \(configurationAssembly.configuration.featureEnabled(flag).displayText)",
                        color: localValueColor,
                        textStyle: .body2
                    )
                ),
                onSelection: { _ in
                    ToastPresenter.showToast(
                        configuration: .defaultConfiguration(text: "Feature is disabled via keys/all")
                    )
                }
            )
        }

        return SettingsListItem(
            id: "featureFlag_\(flag.localKey)",
            cellConfiguration: cellConfiguration,
            accessory: .text(
                TKListItemTextAccessoryView.Configuration(
                    text: "resolved: \(resolvedValue.displayText)\ntap to override",
                    color: localValueColor,
                    textStyle: .body2,
                    numberOfLines: 2,
                    menu: menu
                )
            ),
            onSelection: nil
        )
    }
}

private extension Bool {
    var displayText: String {
        self ? "true" : "false"
    }
}

private extension Optional where Wrapped == Bool {
    var displayText: String {
        switch self {
        case .none:
            "no flag"
        case let .some(value):
            value.displayText
        }
    }
}
