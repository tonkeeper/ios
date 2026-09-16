import Foundation
import KeeperCore
import SwiftUI
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import TonSwift
import UIKit

struct WalletMigrationItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let tags: [TKTagSwiftUIViewConfig]
    let icon: UIImage
    let iconBackgroundColor: TKColor
}

@MainActor
final class WalletMigrationViewModel: ObservableObject {
    enum State {
        case loading
        case wallets([WalletMigrationItem])
        case empty
        case failed
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var selectedWalletId: String?
    @Published private(set) var isContinueEnabled = false

    var didRequestClose: (() -> Void)?
    var didTapContinue: ((String) -> Void)?
    var didTapAddTonWallet: (() -> Void)?
    var didTapHowItWorks: (() -> Void)?
    var didDetectNoMigratableWallets: (() -> Void)?

    private let walletsStore: WalletsStore
    private let walletMigrationService: WalletMigrationService
    private let amountFormatter: AmountFormatter
    private let currencyStore: CurrencyStore
    private let appSettingsStore: AppSettingsStore
    private let analyticsProvider: AnalyticsProvider

    private var isScreenVisible = false
    private var hasLoggedSelectionView = false
    private var observesStores = false
    private var reloadTask: Task<Void, Never>?
    private var reloadID: UUID?

    init(
        walletsStore: WalletsStore,
        walletMigrationService: WalletMigrationService,
        amountFormatter: AmountFormatter,
        currencyStore: CurrencyStore,
        appSettingsStore: AppSettingsStore,
        analyticsProvider: AnalyticsProvider
    ) {
        self.walletsStore = walletsStore
        self.walletMigrationService = walletMigrationService
        self.amountFormatter = amountFormatter
        self.currencyStore = currencyStore
        self.appSettingsStore = appSettingsStore
        self.analyticsProvider = analyticsProvider
    }

    func start() async {
        observeStores()
        await reloadItems()
    }

    func screenAppeared() {
        isScreenVisible = true
        logSelectionViewIfListShown()
    }

    func screenDisappeared() {
        isScreenVisible = false
    }

    func selectWallet(id: String) {
        selectedWalletId = id
        isContinueEnabled = true
    }

    func continueTapped() {
        guard let selectedWalletId else { return }
        analyticsProvider.log(MigrateWalletSelectionClick())
        didTapContinue?(selectedWalletId)
    }

    func addTonWalletTapped() {
        didTapAddTonWallet?()
    }

    func howItWorksTapped() {
        didTapHowItWorks?()
    }

    func retry() async {
        await reloadItems()
    }

    var items: [WalletMigrationItem] {
        if case let .wallets(items) = state {
            return items
        }
        return []
    }

    private func observeStores() {
        guard !observesStores else { return }
        observesStores = true
        walletsStore.addObserver(self) { [weak self] _, event in
            Task { @MainActor in
                switch event {
                case .didAddWallets, .didDeleteWallet, .didUpdateWalletMetaData, .didUpdateWalletMultichain:
                    await self?.reloadItems()
                default:
                    break
                }
            }
        }
    }

    private func reloadItems() async {
        reloadTask?.cancel()

        let reloadID = UUID()
        self.reloadID = reloadID
        let task = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            await self.performReload(id: reloadID)
        }
        reloadTask = task

        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }

        guard self.reloadID == reloadID else { return }
        reloadTask = nil
    }

    private func performReload(id: UUID) async {
        let candidateWallets = walletsStore.wallets.filter {
            WalletMigrationVisibility.isLegacyTonWallet($0)
        }

        guard !candidateWallets.isEmpty else {
            guard isCurrentReload(id) else { return }
            applyLoadedItems([])
            return
        }

        // Store-event and back-from-confirmation reloads refresh the visible list
        // in place instead of flashing the skeleton and dropping the selection.
        switch state {
        case .wallets:
            break
        default:
            state = .loading
        }

        do {
            let migrationValues = try await walletMigrationService.getMigrationWallets(
                wallets: candidateWallets,
                currency: currencyStore.state
            )
            guard isCurrentReload(id) else { return }

            let items = makeItems(wallets: candidateWallets, values: migrationValues)
            applyLoadedItems(items)
        } catch {
            guard isCurrentReload(id) else { return }
            Log.migration.w("picker load failed", error: error)
            guard case .loading = state else { return }
            state = .failed
            selectedWalletId = nil
            isContinueEnabled = false
        }
    }

    private func isCurrentReload(_ id: UUID) -> Bool {
        reloadID == id && !Task.isCancelled
    }

    private func makeItems(wallets: [Wallet], values: [WalletMigrationWalletValue]) -> [WalletMigrationItem] {
        wallets
            .compactMap { wallet -> (wallet: Wallet, value: WalletMigrationWalletValue)? in
                guard let value = values.first(where: { matches(account: $0.account, wallet: wallet) }),
                      value.hasMigratableAssets
                else {
                    return nil
                }

                return (wallet, value)
            }
            .sorted { $0.value.fiatBalance > $1.value.fiatBalance }
            .map { makeItem(wallet: $0.wallet, value: $0.value) }
    }

    /// The event means "the picker listed something", so it waits for the list instead of
    /// firing on appearance: an empty or failed load is a drop before the picker, not a view.
    /// Once per view model, i.e. once per `migration_start`: returning from the confirmation
    /// screen must not add a view the funnel would read as a second attempt.
    private func logSelectionViewIfListShown() {
        guard isScreenVisible, !hasLoggedSelectionView, case .wallets = state else { return }
        hasLoggedSelectionView = true
        analyticsProvider.log(MigrateWalletSelectionView())
    }

    private func applyLoadedItems(_ items: [WalletMigrationItem]) {
        if items.isEmpty {
            if let didDetectNoMigratableWallets {
                didDetectNoMigratableWallets()
                return
            }
            state = .empty
        } else {
            state = .wallets(items)
        }

        logSelectionViewIfListShown()

        if let selectedWalletId,
           items.contains(where: { $0.id == selectedWalletId })
        {
            isContinueEnabled = true
        } else if let firstItem = items.first {
            selectedWalletId = firstItem.id
            isContinueEnabled = true
        } else {
            selectedWalletId = nil
            isContinueEnabled = false
        }
    }

    private func makeItem(wallet: Wallet, value: WalletMigrationWalletValue) -> WalletMigrationItem {
        WalletMigrationItem(
            id: wallet.id,
            title: wallet.label,
            subtitle: makeSubtitle(value: value),
            tags: wallet.listTagSwiftUIConfigurations(),
            icon: makeIcon(wallet: wallet),
            iconBackgroundColor: wallet.tintColor.themedColor
        )
    }

    private func makeSubtitle(value: WalletMigrationWalletValue) -> String {
        var parts = [String]()

        if appSettingsStore.state.isSecureMode {
            parts.append(String.secureModeValueShort)
        } else {
            parts.append(
                amountFormatter.format(
                    decimal: value.fiatBalance,
                    accessory: .fiat(currencyStore.state),
                    style: .fiatBalance
                )
            )
        }

        if value.nftCount > 0 {
            let nftsTitle = value.nftCount == 1
                ? TKLocales.Settings.Migration.nftCount(value.nftCount)
                : TKLocales.Settings.Migration.nftsCount(value.nftCount)
            parts.append(nftsTitle)
        }

        return parts.joined(separator: " · ")
    }

    private func makeIcon(wallet: Wallet) -> UIImage {
        switch wallet.icon {
        case let .icon(image):
            return image.image ?? .TKUIKit.Icons.Size16.walletAvatarWallet
        case .emoji:
            return .TKUIKit.Icons.Size16.walletAvatarWallet
        }
    }

    private func matches(account: String, wallet: Wallet) -> Bool {
        guard let walletAddress = try? wallet.tonMigrationAccountId(),
              let lhs = try? Address.parse(walletAddress),
              let rhs = try? Address.parse(account)
        else {
            return false
        }

        return lhs == rhs
    }
}
