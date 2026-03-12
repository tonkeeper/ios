import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

final class SettingsListCurrencyPickerConfigurator: SettingsListConfigurator {
    var didSelect: (() -> Void)?

    // MARK: - SettingsListV2Configurator

    var didUpdateState: ((SettingsListState) -> Void)?
    var title: String {
        TKLocales.Currency.title
    }

    var selectedItems = Set<SettingsListItem>()

    func getInitialState() -> SettingsListState {
        createState()
    }

    // MARK: - Dependencies

    private let currencyStore: CurrencyStore
    private let configuration: Configuration

    // MARK: - Init

    init(currencyStore: CurrencyStore, configuration: Configuration) {
        self.currencyStore = currencyStore
        self.configuration = configuration
    }

    private func createState() -> SettingsListState {
        let selectedCurrency = currencyStore.getState()
        var currencies = Currency.allCases

        if configuration.isGB {
            currencies.remove(.RUB)
            currencies.remove(.BYN)
        }

        var items = [SettingsListItem]()
        for currency in currencies {
            let cellConfiguration = TKListItemCell.Configuration(
                listItemContentViewConfiguration: TKListItemContentView.Configuration(
                    textContentViewConfiguration: TKListItemTextContentView.Configuration(
                        titleViewConfiguration: TKListItemTitleView.Configuration(
                            title: currency.code,
                            caption: currency.title
                        )
                    )
                )
            )
            let item = SettingsListItem(
                id: currency.code,
                cellConfiguration: cellConfiguration,
                accessory: .none,
                selectAccessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.donemarkOutline, tintColor: .Accent.blue)),
                onSelection: { [weak self] _ in
                    guard let self else { return }
                    Task {
                        await self.currencyStore.setCurrency(currency)
                        await MainActor.run {
                            self.didSelect?()
                        }
                    }
                }
            )
            items.append(item)

            if currency == selectedCurrency {
                selectedItems.removeAll()
                selectedItems.insert(item)
            }
        }

        let section = SettingsListSection.listItems(
            SettingsListItemsSection(
                items: items.map(SettingsListItemsSectionItem.listItem)
            )
        )

        return SettingsListState(sections: [section])
    }
}

private extension Configuration {
    var isGB: Bool {
        value(\.region) == "GB"
    }
}
