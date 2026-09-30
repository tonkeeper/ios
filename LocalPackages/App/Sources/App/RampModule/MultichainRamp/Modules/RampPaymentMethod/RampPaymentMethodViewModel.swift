import Foundation
import KeeperCore
import SwiftUI
import TKLocalize
import TKLogging
import TKUIKit

@MainActor
final class RampPaymentMethodViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded
        case failed
    }

    let asset: MultichainAsset
    let flow: RampFlow

    var onClose: (() -> Void)?
    var onBack: (() -> Void)?
    var onSelectCurrency: (([RemoteCurrency], RemoteCurrency) -> Void)?
    var onSelectPaymentMethod: ((RampPaymentMethodRow, RemoteCurrency, OnRampAssetDetail) -> Void)?

    @Published private(set) var state: State = .loading
    @Published private(set) var rows: [RampPaymentMethodRow] = []
    @Published private(set) var currentCurrency: RemoteCurrency?

    private let preferredFiat: String?
    private let multichainRampService: MultichainRampService
    private let currenciesService: CurrenciesService
    private let currencyStore: CurrencyStore
    private let walletId: String?

    private var assetDetail: OnRampAssetDetail?
    private var currencies: [RemoteCurrency] = []
    private var methodsTask: Task<Void, Never>?

    init(
        asset: MultichainAsset,
        flow: RampFlow,
        preferredFiat: String? = nil,
        multichainRampService: MultichainRampService,
        currenciesService: CurrenciesService,
        currencyStore: CurrencyStore,
        walletId: String?
    ) {
        self.asset = asset
        self.flow = flow
        self.preferredFiat = preferredFiat
        self.multichainRampService = multichainRampService
        self.currenciesService = currenciesService
        self.currencyStore = currencyStore
        self.walletId = walletId
    }

    var placeholderKind: PaymentMethodPlaceholderOverlayKind? {
        switch state {
        case .loading:
            return nil
        case .failed:
            return .loadError
        case .loaded:
            return rows.isEmpty ? .emptyNoCashForCurrency : nil
        }
    }

    var screenTitle: String {
        switch flow {
        case .deposit:
            return TKLocales.Ramp.Deposit.PaymentMethod.title
        case .withdraw:
            return TKLocales.Ramp.Withdraw.PaymentMethod.sellToCash
        }
    }

    var currencySubtitleCaption: String {
        switch flow {
        case .deposit:
            return TKLocales.Ramp.Deposit.fiatCurrencyRowCaption
        case .withdraw:
            return TKLocales.Ramp.Withdraw.fiatCurrencyRowCaption
        }
    }

    var currencyCode: String {
        currentCurrency?.code ?? currencyStore.state.code
    }

    func viewDidLoad() {
        Task {
            await loadData()
        }
    }

    func close() {
        onClose?()
    }

    func back() {
        onBack?()
    }

    func tapCurrency() {
        guard let currentCurrency, !currencies.isEmpty else {
            return
        }
        onSelectCurrency?(currencies, currentCurrency)
    }

    func setCurrency(_ currency: RemoteCurrency) {
        guard currency.code != currentCurrency?.code else {
            return
        }
        currentCurrency = currency
        rows = []
        state = .loading
        methodsTask?.cancel()
        methodsTask = Task { [weak self] in
            await self?.loadMethods(fiat: currency.code)
        }
    }

    func select(row: RampPaymentMethodRow) {
        guard let currentCurrency, let assetDetail else {
            Log.multichainRamp.w(
                "payment method tap ignored - screen not loaded",
                extraInfo: logInfo.merging(["row": row.type]) { _, new in new }
            )
            return
        }
        onSelectPaymentMethod?(row, currentCurrency, assetDetail)
    }

    func retry() {
        Task {
            await loadData()
        }
    }
}

private extension RampPaymentMethodViewModel {
    func loadData() async {
        methodsTask?.cancel()
        state = .loading
        rows = []

        do {
            async let currenciesTask = currenciesService.loadCurrencies()
            let loadedAssetDetail: OnRampAssetDetail
            switch flow {
            case .deposit:
                loadedAssetDetail = try await multichainRampService.getOnrampAsset(
                    assetId: asset.asset.assetId,
                    fiat: nil,
                    walletId: walletId
                )
            case .withdraw:
                let offRampAssetDetail = try await multichainRampService.getOfframpAsset(
                    assetId: asset.asset.assetId
                )
                loadedAssetDetail = offRampAssetDetail.paymentMethodAssetDetail
            }

            let allCurrencies = try await currenciesTask
            assetDetail = loadedAssetDetail

            let supportedFiats = Set(assetDetail?.supportedFiats ?? [])
            currencies = allCurrencies.filter {
                $0.currencyType == .fiat && supportedFiats.contains($0.code)
            }

            resolveCurrentCurrency(
                preferredCurrencyCode: preferredFiat,
                storeCurrencyCode: currencyStore.state.code
            )

            await loadMethods(fiat: currencyCode)
        } catch {
            state = .failed
            Log.multichainRamp.failure("payment methods loading failed", error: error, extraInfo: logInfo)
        }
    }

    func loadMethods(fiat: String) async {
        let fiatLogInfo = logInfo.merging(["fiat": fiat]) { _, new in new }
        do {
            let detail = try await methodsDetail(fiat: fiat)
            guard !Task.isCancelled, currentCurrency?.code == fiat else {
                Log.multichainRamp.i("payment methods response dropped - currency changed", extraInfo: fiatLogInfo)
                return
            }
            assetDetail = detail
            applyPaymentMethods()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, currentCurrency?.code == fiat else { return }
            rows = []
            state = .loaded
            Log.multichainRamp.failure("payment methods loading failed for currency", error: error, extraInfo: fiatLogInfo)
        }
    }

    func methodsDetail(fiat: String) async throws -> OnRampAssetDetail? {
        switch flow {
        case .deposit:
            return try await multichainRampService.getOnrampAsset(
                assetId: asset.asset.assetId,
                fiat: fiat,
                walletId: walletId
            )
        case .withdraw:
            return assetDetail
        }
    }

    var logInfo: [String: String] {
        [
            "flow": flow.api,
            "assetId": asset.asset.assetId,
            "preferredFiat": preferredFiat ?? "",
            "storeCurrency": currencyStore.state.code,
        ]
    }

    func resolveCurrentCurrency(preferredCurrencyCode: String?, storeCurrencyCode: String) {
        if let currentCurrency,
           currencies.contains(where: { $0.code == currentCurrency.code })
        {
            return
        }

        let currencyCode = preferredCurrencyCode ?? storeCurrencyCode
        currentCurrency = currencies.first(where: { $0.code == currencyCode }) ?? .default
    }

    func applyPaymentMethods() {
        guard let assetDetail else {
            rows = []
            state = .failed
            Log.multichainRamp.w("payment methods unavailable - no asset detail", extraInfo: logInfo)
            return
        }

        let fiat = (currentCurrency ?? .default).code
        rows = RampPaymentMethodRow.rows(from: assetDetail, fiat: fiat)
        state = .loaded
        if rows.isEmpty {
            Log.multichainRamp.i(
                "no payment methods for currency",
                extraInfo: logInfo.merging(["fiat": fiat]) { _, new in new }
            )
        }
    }
}

private extension OnRampAssetDetail {
    var supportedFiats: [String] {
        Set(
            paymentMethods.flatMap { method in
                method.providers.map(\.fiat)
            }
        ).sorted()
    }
}
