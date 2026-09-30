import Foundation
import KeeperCore
import TKCore
import TKUIKit

protocol PaymentMethodModuleOutput: AnyObject {
    var didTapClose: (() -> Void)? { get set }
    var didTapBack: (() -> Void)? { get set }
    var didSelectCashMethod: ((OnRampLayoutCashMethod, OnRampLayout, RemoteCurrency) -> Void)? { get set }
    var didSelectCryptoMethod: ((OnRampLayoutCryptoMethod) -> Void)? { get set }
    var didTapAllCryptoMethods: (([OnRampLayoutCryptoMethod]) -> Void)? { get set }
    var didSelectCurrency: (([RemoteCurrency], RemoteCurrency) -> Void)? { get set }
    var didSelectStablecoin: (([OnRampLayoutCryptoMethod]) -> Void)? { get set }
}

protocol PaymentMethodModuleInput: AnyObject {
    func set(currency: RemoteCurrency)
}

protocol PaymentMethodViewModelProtocol: AnyObject {
    var didUpdateSnapshot: ((PaymentMethodViewController.Snapshot) -> Void)? { get set }
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
    var currentCurrency: RemoteCurrency? { get }
    var placeholderOverlayKind: PaymentMethodPlaceholderOverlayKind? { get }

    func viewDidLoad()
    func didTapCloseButton()
    func didTapBackButton()
    func didTapCurrencyButton()
    func didSelect(item: PaymentMethodViewController.Item)
    func retry()
}

final class PaymentMethodViewModelImplementation: PaymentMethodViewModelProtocol, PaymentMethodModuleOutput, PaymentMethodModuleInput {
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed
    }

    var didTapClose: (() -> Void)?
    var didTapBack: (() -> Void)?
    var didSelectCashMethod: ((OnRampLayoutCashMethod, OnRampLayout, RemoteCurrency) -> Void)?
    var didSelectCryptoMethod: ((OnRampLayoutCryptoMethod) -> Void)?
    var didTapAllCryptoMethods: (([OnRampLayoutCryptoMethod]) -> Void)?
    var didSelectCurrency: (([RemoteCurrency], RemoteCurrency) -> Void)?
    var didSelectStablecoin: (([OnRampLayoutCryptoMethod]) -> Void)?

    var didUpdateSnapshot: ((PaymentMethodViewController.Snapshot) -> Void)?
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?

    var currentCurrency: RemoteCurrency?

    let flow: RampFlow
    var asset: RampAsset
    var onRampLayout: OnRampLayout?
    var rampLayoutItem: OnRampLayoutItem

    private let isTRC20Available: Bool
    private let onRampService: OnRampService
    private let currencyStore: CurrencyStore
    private let currenciesService: CurrenciesService
    private let initialDeeplink: RampDeeplinkParameters?
    private let walletId: String?

    var currencies: [RemoteCurrency] = []
    var state: LoadState = .loading
    private var didApplyInitialDeeplink = false

    init(
        flow: RampFlow,
        asset: RampAsset,
        rampLayoutItem: OnRampLayoutItem,
        isTRC20Available: Bool,
        onRampService: OnRampService,
        currencyStore: CurrencyStore,
        currenciesService: CurrenciesService,
        initialDeeplink: RampDeeplinkParameters?,
        fiatCurrency: RemoteCurrency?,
        walletId: String?
    ) {
        self.flow = flow
        self.asset = asset
        self.rampLayoutItem = rampLayoutItem
        self.isTRC20Available = isTRC20Available
        self.onRampService = onRampService
        self.currencyStore = currencyStore
        self.currenciesService = currenciesService
        self.initialDeeplink = initialDeeplink
        self.currentCurrency = fiatCurrency
        self.walletId = walletId
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

    func retry() {
        Task { @MainActor in
            await loadData()
        }
    }

    func didSelect(item: PaymentMethodViewController.Item) {
        switch item {
        case .warningBanner:
            break
        case .shimmer:
            break
        case let .cashMethod(method):
            if let currentCurrency, let onRampLayout {
                didSelectCashMethod?(method, onRampLayout, currentCurrency)
            }
        case let .cryptoMethod(method):
            didSelectCryptoMethod?(method)
        case .allCryptoMethods:
            didTapAllCryptoMethods?(asset.cryptoMethods)
        case let .stablecoin(_, _, networkMethods):
            if !networkMethods.isEmpty {
                didSelectStablecoin?(networkMethods)
            }
        }
    }

    @MainActor
    private func loadData() async {
        state = .loading
        buildSnapshot()

        do {
            let allCurrencies = try await currenciesService.loadCurrencies()
            let currencies = allCurrencies.filter { $0.currencyType == .fiat }
            let currencyCode = rampLayoutItem.preferredCurrency ?? currencyStore.getState().code
            if currentCurrency == nil {
                let value = currencies.first(where: { $0.code == currencyCode })
                currentCurrency = value ?? .default
            }
            self.currencies = currencies

            let onRampLayout = try await onRampService
                .getLayout(
                    flow: flow.api,
                    currency: currentCurrency?.code ?? currencyCode,
                    walletId: walletId
                )
                .filteredByTRC20Availability(isAvailable: isTRC20Available)
            if let item = onRampLayout.items.first(where: { $0.type == rampLayoutItem.type }), let asset = item.assets?.first(where: { $0.symbol == asset.symbol && $0.network == asset.network && $0.networkName == asset.networkName && $0.assetId == asset.assetId }) {
                self.asset = asset
                self.rampLayoutItem = item
            }
            self.onRampLayout = onRampLayout
        } catch {
            onRampLayout = nil
            state = .failed
            buildSnapshot()
            return
        }

        state = .loaded
        buildSnapshot()
        if hasContent {
            applyInitialPaymentDeeplinkIfNeeded()
        }
    }

    @MainActor
    private func applyInitialPaymentDeeplinkIfNeeded() {
        guard !didApplyInitialDeeplink, let params = initialDeeplink, let onRampLayout else { return }

        if let filter = params.itemType, filter != rampLayoutItem.type {
            didApplyInitialDeeplink = true
            return
        }

        didApplyInitialDeeplink = true

        if let crypto = resolveCryptoMethodForPaymentDeeplink(params) {
            switch rampLayoutItem.type {
            case .stablecoin:
                didSelectStablecoin?([crypto])
                return
            case .crypto:
                didSelectCryptoMethod?(crypto)
                return
            case .fiat:
                break
            }
        }

        let cmTrimmed = params.cashMethod?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !cmTrimmed.isEmpty else { return }
        guard let method = RampDeeplinkMatching.matchCashMethod(in: asset.cashMethods, cashMethod: params.cashMethod) else { return }
        guard let currency = currentCurrency else { return }
        didSelectCashMethod?(method, onRampLayout, currency)
    }

    /// Prefers `tt` / `tn` (destination rail on swap); if `tt` is empty, uses `ft` / `fn` for the payment / withdrawal route.
    private func resolveCryptoMethodForPaymentDeeplink(_ params: RampDeeplinkParameters) -> OnRampLayoutCryptoMethod? {
        let tt = params.toToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !tt.isEmpty {
            return RampDeeplinkMatching.matchCryptoMethod(
                in: asset.cryptoMethods,
                toToken: params.toToken,
                toNetwork: params.toNetwork
            )
        }
        let ft = params.fromToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !ft.isEmpty {
            return RampDeeplinkMatching.matchCryptoMethod(
                in: asset.cryptoMethods,
                toToken: params.fromToken,
                toNetwork: params.fromNetwork
            )
        }
        return nil
    }
}
