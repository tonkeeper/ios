import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

final class SettingsListCurrencyPickerConfigurator: SettingsListConfigurator {
    var didSelect: (() -> Void)?

    // MARK: - SettingsListConfigurator

    var didUpdateState: ((SettingsListState) -> Void)?
    var title: String {
        TKLocales.Currency.title
    }

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

        let items = currencies.map { currency in
            SettingsListItem(
                id: currency.code,
                title: SettingsListItemTitle(currency.code),
                inlineCaption: currency.title,
                accessory: currency == selectedCurrency
                    ? .icon(.TKUIKit.Icons.Size28.donemarkOutline, tintColor: .accentBlue)
                    : .none,
                onTap: { [weak self] _ in
                    guard let self else { return }
                    Task {
                        await self.currencyStore.setCurrency(currency)
                        await MainActor.run {
                            self.didSelect?()
                        }
                    }
                }
            )
        }

        let section = SettingsListSection.items(
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
