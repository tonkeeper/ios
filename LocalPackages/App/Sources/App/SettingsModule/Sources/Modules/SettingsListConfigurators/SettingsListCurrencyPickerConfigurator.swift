import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

final class SettingsListCurrencyPickerConfigurator: SettingsListConfigurator {
    struct Entry: Equatable {
        let currency: Currency
        let displayCode: String
        let name: String
    }

    var didSelect: (() -> Void)?

    // MARK: - SettingsListConfigurator

    var didUpdateState: ((SettingsListState) -> Void)?
    var title: String {
        TKLocales.Currency.title
    }

    func getInitialState() -> SettingsListState {
        loadCurrencies()
        return createState()
    }

    // MARK: - Dependencies

    private let currencyStore: CurrencyStore
    private let currenciesService: CurrenciesService
    private let isRestrictedRegion: () -> Bool

    // MARK: - State

    private var entries: [Entry] = []

    // MARK: - Init

    init(
        currencyStore: CurrencyStore,
        currenciesService: CurrenciesService,
        isRestrictedRegion: @escaping () -> Bool
    ) {
        self.currencyStore = currencyStore
        self.currenciesService = currenciesService
        self.isRestrictedRegion = isRestrictedRegion
    }

    static func entries(from remoteCurrencies: [RemoteCurrency]) -> [Entry] {
        remoteCurrencies.compactMap { remote in
            guard let currency = Currency(code: remote.code) else { return nil }
            return Entry(currency: currency, displayCode: remote.code, name: remote.name)
        }
    }

    private func loadCurrencies() {
        Task { [weak self] in
            guard let self, let remoteCurrencies = try? await currenciesService.loadCurrencies() else { return }
            let entries = Self.entries(from: remoteCurrencies)
            await MainActor.run {
                guard entries != self.entries else { return }
                self.entries = entries
                self.didUpdateState?(self.createState())
            }
        }
    }

    private static let restrictedRegionCodes: Set<String> = ["RUB", "BYN"]

    private func createState() -> SettingsListState {
        let selectedCurrency = currencyStore.getState()
        var entries = entries

        if !entries.contains(where: { $0.currency == selectedCurrency }) {
            entries.insert(
                Entry(
                    currency: selectedCurrency,
                    displayCode: selectedCurrency.code,
                    name: selectedCurrency.code
                ),
                at: 0
            )
        }
        if isRestrictedRegion() {
            entries.removeAll { Self.restrictedRegionCodes.contains($0.currency.code) }
        }

        let items = entries.map { entry in
            SettingsListItem(
                id: entry.currency.code,
                title: SettingsListItemTitle(entry.displayCode),
                inlineCaption: entry.name,
                accessory: entry.currency == selectedCurrency
                    ? .icon(.TKUIKit.Icons.Size28.donemarkOutline, tintColor: .accentBlue)
                    : .none,
                onTap: { [weak self] _ in
                    guard let self else { return }
                    Task {
                        await self.currencyStore.setCurrency(entry.currency)
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
