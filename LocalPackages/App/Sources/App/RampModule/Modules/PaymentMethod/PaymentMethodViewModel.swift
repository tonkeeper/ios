import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol PaymentMethodModuleOutput: AnyObject {
    var didTapClose: (() -> Void)? { get set }
    var didTapBack: (() -> Void)? { get set }
    var didSelectCashMethod: ((OnRampLayoutCashMethod, OnRampLayout, RemoteCurrency) -> Void)? { get set }
    var didSelectCryptoAsset: ((OnRampLayoutCryptoMethod) -> Void)? { get set }
    var didTapAllMethods: (([OnRampLayoutCashMethod], OnRampLayout, RemoteCurrency) -> Void)? { get set }
    var didTapAllAssets: (([OnRampLayoutCryptoMethod]) -> Void)? { get set }
    var didSelectCurrency: (([RemoteCurrency], RemoteCurrency) -> Void)? { get set }
    var didSelectStablecoin: (([OnRampLayoutCryptoMethod]) -> Void)? { get set }
}

protocol PaymentMethodModuleInput: AnyObject {
    func set(currency: RemoteCurrency)
}

protocol PaymentMethodViewModelProtocol: AnyObject {
    var didUpdateSnapshot: ((PaymentMethodViewController.Snapshot) -> Void)? { get set }
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
    var didShowError: ((String) -> Void)? { get set }
    var currentCurrency: RemoteCurrency? { get }

    func viewDidLoad()
    func didTapCloseButton()
    func didTapBackButton()
    func didTapCurrencyButton()
    func didSelect(item: PaymentMethodViewController.Item)
}

final class PaymentMethodViewModelImplementation: PaymentMethodViewModelProtocol, PaymentMethodModuleOutput, PaymentMethodModuleInput {
    var didTapClose: (() -> Void)?
    var didTapBack: (() -> Void)?
    var didSelectCashMethod: ((OnRampLayoutCashMethod, OnRampLayout, RemoteCurrency) -> Void)?
    var didSelectCryptoAsset: ((OnRampLayoutCryptoMethod) -> Void)?
    var didTapAllMethods: (([OnRampLayoutCashMethod], OnRampLayout, RemoteCurrency) -> Void)?
    var didTapAllAssets: (([OnRampLayoutCryptoMethod]) -> Void)?
    var didSelectCurrency: (([RemoteCurrency], RemoteCurrency) -> Void)?
    var didSelectStablecoin: (([OnRampLayoutCryptoMethod]) -> Void)?

    var didUpdateSnapshot: ((PaymentMethodViewController.Snapshot) -> Void)?
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
    var didShowError: ((String) -> Void)?

    var currentCurrency: RemoteCurrency?

    let flow: RampFlow
    var asset: RampAsset
    var onRampLayout: OnRampLayout
    private let isTRC20Available: Bool
    private let onRampService: OnRampService
    private let currencyStore: CurrencyStore
    private let currenciesService: CurrenciesService

    var currencies: [RemoteCurrency] = []
    var isLoading = true

    init(
        flow: RampFlow,
        asset: RampAsset,
        onRampLayout: OnRampLayout,
        isTRC20Available: Bool,
        onRampService: OnRampService,
        currencyStore: CurrencyStore,
        currenciesService: CurrenciesService
    ) {
        self.flow = flow
        self.asset = asset
        self.onRampLayout = onRampLayout
        self.isTRC20Available = isTRC20Available
        self.onRampService = onRampService
        self.currencyStore = currencyStore
        self.currenciesService = currenciesService
    }

    func viewDidLoad() {
        didUpdateTitleView?(TKUINavigationBarTitleView.Model(title: title))
        Task { @MainActor in
            await loadData()
        }
    }

    func didTapCloseButton() {
        didTapClose?()
    }

    func didTapBackButton() {
        didTapBack?()
    }

    func didTapCurrencyButton() {
        if let currentCurrency {
            didSelectCurrency?(currencies, currentCurrency)
        }
    }

    func set(currency: RemoteCurrency) {
        currentCurrency = currency
        Task { @MainActor in
            await loadData()
        }
    }

    func didSelect(item: PaymentMethodViewController.Item) {
        switch item {
        case .shimmer:
            break
        case let .cashMethod(method):
            if let currentCurrency {
                didSelectCashMethod?(method, onRampLayout, currentCurrency)
            }
        case let .cryptoAsset(asset):
            didSelectCryptoAsset?(asset)
        case .allMethods:
            if let currentCurrency {
                didTapAllMethods?(asset.cashMethods, onRampLayout, currentCurrency)
            }
        case .allAssets:
            didTapAllAssets?(asset.cryptoMethods)
        case let .stablecoin(_, _, networkMethods):
            if !networkMethods.isEmpty {
                didSelectStablecoin?(networkMethods)
            }
        }
    }

    @MainActor
    private func loadData() async {
        isLoading = true
        buildSnapshot()

        do {
            let allCurrencies = try await currenciesService.loadCurrencies()
            let currencies = allCurrencies.filter { $0.currencyType == .fiat }
            let currencyCode = currencyStore.getState().code
            if currentCurrency == nil {
                let value = currencies.first(where: { $0.code == currencyCode })
                currentCurrency = value ?? .default
            }
            self.currencies = currencies

            onRampLayout = try await onRampService
                .getLayout(flow: flow.api, currency: currentCurrency?.code ?? currencyCode)
                .filteredByTRC20Availability(isAvailable: isTRC20Available)
            if let asset = onRampLayout.assets.first(where: { $0.symbol == asset.symbol && $0.network == asset.network }) {
                self.asset = asset
            }
        } catch {
            didShowError?(TKLocales.Errors.unknown)
        }

        isLoading = false
        buildSnapshot()
    }
}
