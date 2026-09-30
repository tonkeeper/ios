import KeeperCore
import TKFeatureFlags
import TKUIKit
import UIKit

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

        let sections: [SettingsListSection] = [
            .items(
                SettingsListItemsSection(
                    items: sortedFlags.compactMap(createFlagItem).map(SettingsListItemsSectionItem.listItem),
                    header: SettingsListSectionHeader(title: "Allowed by keys/all")
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
        let bundleValue = value.bundleValue
        let localValue = value.localValue
        let remoteValue = value.remoteValue
        let defaultValue = value.defaultValue
        let resolvedValue = configurationAssembly.configuration.featureEnabled(flag)

        let titleColor: TKColor = .textPrimary
        let detailsColor: TKColor = .textSecondary
        let localValueColor: TKColor = .textPrimary

        var captions = [
            SettingsListItemCaption("remote: \(remoteValue.displayText)", color: detailsColor),
            SettingsListItemCaption("local: \(localValue.displayText)", color: detailsColor),
            SettingsListItemCaption("default: \(defaultValue.displayText)", color: detailsColor),
        ]
        if bundleValue != nil {
            captions.insert(
                SettingsListItemCaption("bundle: \(bundleValue.displayText)", color: detailsColor),
                at: 0
            )
        }

        let applyOverride: (Bool?) -> Void = { [weak self] overrideValue in
            guard let self else { return }
            if let overrideValue {
                self.featureFlags[flag] = overrideValue
            } else {
                self.featureFlags.resetValue(for: flag)
            }
            self.didUpdateState?(self.createState())
            ToastPresenter.showToast(
                configuration: .defaultConfiguration(
                    text: bundleValue == nil
                        ? "Restart the app to apply"
                        : "Ignored: forced by bundled FlagsOverride.json"
                )
            )
        }

        return SettingsListItem(
            id: "featureFlag_\(flag.localKey)",
            title: SettingsListItemTitle(flag.localKey),
            titleColor: titleColor,
            captions: captions,
            accessory: .menu(
                SettingsListItemMenuAccessory(
                    label: SettingsListItemTextAccessory(
                        text: "resolved: \(resolvedValue.displayText)\ntap to override",
                        color: localValueColor,
                        lineLimit: 2
                    ),
                    options: [
                        SettingsListItemMenuOption(
                            title: "default",
                            isSelected: localValue == nil,
                            action: { applyOverride(nil) }
                        ),
                        SettingsListItemMenuOption(
                            title: "force true",
                            isSelected: localValue == true,
                            action: { applyOverride(true) }
                        ),
                        SettingsListItemMenuOption(
                            title: "force false",
                            isSelected: localValue == false,
                            action: { applyOverride(false) }
                        ),
                    ]
                )
            )
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
