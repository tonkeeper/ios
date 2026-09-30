import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol RampModuleOutput: AnyObject {
    var didTapReceiveTokens: (() -> Void)? { get set }
    var didTapSendTokens: (() -> Void)? { get set }
    var didTapLayoutItem: ((OnRampLayoutItem, OnRampLayout, RampDeeplinkParameters?, RampAsset?) -> Void)? { get set }
    var didOpenScreen: ((OnRampLayout) -> Void)? { get set }
    var didSelectFiatCurrency: (([RemoteCurrency], RemoteCurrency) -> Void)? { get set }
    var didClose: (() -> Void)? { get set }
}

protocol RampModuleInput: AnyObject {
    func set(currency: RemoteCurrency)
    var currentFiatCurrency: RemoteCurrency? { get }
}

protocol RampViewModel: AnyObject {
    var didUpdateSnapshot: ((RampViewController.Snapshot) -> Void)? { get set }
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }

    func viewDidLoad()
    func didSelect(item: RampViewController.Item)
    func didTapFiatCurrencyPicker()
    func didTapCloseButton()
    func retry()
}

final class RampViewModelImplementation: RampViewModel, RampModuleOutput, RampModuleInput {
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed
    }

    var didTapReceiveTokens: (() -> Void)?
    var didTapSendTokens: (() -> Void)?
    var didTapLayoutItem: ((OnRampLayoutItem, OnRampLayout, RampDeeplinkParameters?, RampAsset?) -> Void)?
    var didOpenScreen: ((OnRampLayout) -> Void)?
    var didSelectFiatCurrency: (([RemoteCurrency], RemoteCurrency) -> Void)?
    var didClose: (() -> Void)?

    var didUpdateSnapshot: ((RampViewController.Snapshot) -> Void)?
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?

    let flow: RampFlow
    private let wallet: Wallet
    private let onRampService: OnRampService
    private let currenciesService: CurrenciesService
    private let currencyStore: CurrencyStore
    private let initialDeeplink: RampDeeplinkParameters?

    var onRampLayout: OnRampLayout?
    var state: LoadState = .loading
    var currentFiatCurrency: RemoteCurrency?
    var fiatCurrencies: [RemoteCurrency] = []

    init(
        flow: RampFlow,
        wallet: Wallet,
        onRampService: OnRampService,
        currenciesService: CurrenciesService,
        currencyStore: CurrencyStore,
        initialDeeplink: RampDeeplinkParameters? = nil
    ) {
        self.flow = flow
        self.wallet = wallet
        self.onRampService = onRampService
        self.currenciesService = currenciesService
        self.currencyStore = currencyStore
        self.initialDeeplink = initialDeeplink
    }

    func viewDidLoad() {
        buildSnapshot()
        Task { await loadOnRampLayout() }
    }

    @MainActor
    private func loadOnRampLayout() async {
        state = .loading
        buildSnapshot()

        do {
            let allCurrencies = try await currenciesService.loadCurrencies()
            fiatCurrencies = allCurrencies.filter { $0.currencyType == .fiat }
            if currentFiatCurrency == nil {
                let code = currencyStore.getState().code
                currentFiatCurrency = fiatCurrencies.first(where: { $0.code == code }) ?? .default
            }
            let layout = try await onRampService.getLayout(
                flow: flow.api,
                currency: currentFiatCurrency?.code,
                walletId: wallet.multichainWalletId
            )

            onRampLayout = layout
                .filteredByCashOrCryptoAvailability(isAvailable: wallet.isRampCashOrCryptoAvailable)
                .filteredByTRC20Availability(isAvailable: wallet.tron != nil)
            state = .loaded
            buildSnapshot()
            if let onRampLayout {
                didOpenScreen?(onRampLayout)
            }
            applyInitialRampDeeplinkIfNeeded()
        } catch {
            onRampLayout = nil
            state = .failed
            buildSnapshot()
        }
    }

    func didSelect(item: RampViewController.Item) {
        switch item {
        case .receiveTokens:
            didTapReceiveTokens?()
        case .sendTokens:
            didTapSendTokens?()
        case .shimmer:
            break
        case .retry:
            retry()
        case .fiatCurrencyPicker:
            break
        case let .item(item, _):
            if let onRampLayout {
                didTapLayoutItem?(item, onRampLayout, nil, nil)
            }
        }
    }

    func didTapFiatCurrencyPicker() {
        guard let current = currentFiatCurrency else { return }
        didSelectFiatCurrency?(fiatCurrencies, current)
    }

    func set(currency: RemoteCurrency) {
        currentFiatCurrency = currency
        Task { @MainActor in
            await loadOnRampLayout()
        }
    }

    func didTapCloseButton() {
        didClose?()
    }

    func retry() {
        Task { @MainActor in
            await loadOnRampLayout()
        }
    }
}

private extension RampViewModelImplementation {
    @MainActor
    func applyInitialRampDeeplinkIfNeeded() {
        guard let params = initialDeeplink else { return }
        guard let layout = onRampLayout else { return }

        let ftTrimmed = params.fromToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !ftTrimmed.isEmpty {
            let layoutItemsForMatching: [OnRampLayoutItem]
            if let filter = params.itemType {
                layoutItemsForMatching = layout.items.filter { $0.type == filter }
            } else {
                layoutItemsForMatching = layout.items
            }
            let flatAssets = layoutItemsForMatching.flatMap { $0.assets ?? [] }
            guard let asset = RampDeeplinkMatching.matchLayoutAsset(
                in: flatAssets,
                fromToken: params.fromToken,
                fromNetwork: params.fromNetwork
            ) else { return }
            guard !asset.isTronNetwork || wallet.tron != nil else { return }
            guard let layoutItem = layoutItemsForMatching.first(where: { item in
                (item.assets ?? []).contains { $0.assetId == asset.assetId && $0.symbol == asset.symbol && $0.network == asset.network }
            }) else { return }
            didTapLayoutItem?(layoutItem, layout, params, asset)
            return
        }

        if let itemType = params.itemType,
           let layoutItem = layout.items.first(where: { item in
               item.type == itemType && !(item.assets ?? []).isEmpty
           })
        {
            didTapLayoutItem?(layoutItem, layout, params, nil)
        }
    }
}
