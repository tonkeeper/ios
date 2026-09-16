import BigInt
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit

@MainActor
final class InsertAmountViewModel: InsertAmountModuleOutput, InsertAmountModuleInput, InsertAmountViewModelProtocol {
    // MARK: - InsertAmountModuleOutput

    var didTapBack: (() -> Void)?
    var didTapClose: (() -> Void)?
    var didTapContinue: ((RampOnrampContinueContext, OnRampMerchantInfo, URL?) -> Void)?
    var didTapProvider: (([ProviderPickerItem], OnRampMerchantInfo) -> Void)?
    var didLoadInitialMerchant: ((OnRampMerchantInfo?) -> Void)?

    // MARK: - View bindings

    var didUpdateTitle: ((String) -> Void)?
    var didUpdateButton: ((TKButton.Configuration) -> Void)?
    var didUpdateProviderView: ((InsertAmountProviderViewState) -> Void)?
    var didUpdateProviderViewHidden: ((Bool) -> Void)?
    var didShowError: ((String) -> Void)?

    @MainActor
    var isLoading = false {
        didSet {
            didUpdateProviderView?(providerViewState)
            amountInputModuleInput.isConvertedAmountHidden = shouldHideConvertedAmount
            amountInputModuleInput.isConvertedShimmering = isLoading
            updateContinueButton()
        }
    }

    @MainActor
    var isContinueLoading = false {
        didSet {
            updateContinueButton()
        }
    }

    // MARK: - Properties

    var amountInputEnabled = false

    var lastQuotesState: InsertAmountQuotesState?
    var lastCalculatedAmount: BigUInt?

    let flow: RampFlow
    let assetContext: InsertAmountAssetContext
    let paymentMethodContext: InsertAmountPaymentMethodContext
    let currency: RemoteCurrency
    let wallet: Wallet
    let processedBalanceStore: ProcessedBalanceStore
    let quoteService: InsertAmountQuoteServicing
    let amountInputModuleInput: AmountInputModuleInput
    let amountInputModuleOutput: AmountInputModuleOutput
    let amountFormatter: AmountFormatter
    private let analyticsProvider: AnalyticsProvider

    var inputAmount: BigUInt = 0
    var selectedMerchant: OnRampMerchantInfo?
    var availableMerchants: [OnRampMerchantInfo] = []

    var calculateTask: Task<Void, Never>?
    var quoteTask: Task<Void, Never>?
    var quoteRequestGeneration: UInt64 = 0

    var calculatedRate: Decimal?

    var manualProviderChange: Bool = false
    var isInitialAmountLoading: Bool = false
    var hasNotifiedInitialMerchant: Bool = false

    // MARK: - Init

    init(
        flow: RampFlow,
        assetContext: InsertAmountAssetContext,
        paymentMethodContext: InsertAmountPaymentMethodContext,
        currency: RemoteCurrency,
        wallet: Wallet,
        processedBalanceStore: ProcessedBalanceStore,
        quoteService: InsertAmountQuoteServicing,
        amountInputModuleInput: AmountInputModuleInput,
        amountInputModuleOutput: AmountInputModuleOutput,
        amountFormatter: AmountFormatter,
        analyticsProvider: AnalyticsProvider
    ) {
        self.flow = flow
        self.assetContext = assetContext
        self.paymentMethodContext = paymentMethodContext
        self.currency = currency
        self.wallet = wallet
        self.processedBalanceStore = processedBalanceStore
        self.quoteService = quoteService
        self.amountInputModuleInput = amountInputModuleInput
        self.amountInputModuleOutput = amountInputModuleOutput
        self.amountFormatter = amountFormatter
        self.analyticsProvider = analyticsProvider
    }

    // MARK: - Lifecycle

    func viewDidLoad() {
        didUpdateTitle?(TKLocales.Ramp.InsertAmount.title)
        setupAmountInput()
        amountInputModuleInput.isCurrencySwitchEnabled = false
        updateAmountErrorAndContinueButton()
        didUpdateProviderView?(providerViewState)
        didUpdateProviderViewHidden?(true)
        initialLoad()
    }

    // MARK: - Actions

    func didTapBackButton() {
        didTapBack?()
    }

    func didTapCloseButton() {
        didTapClose?()
    }

    func didTapContinueButton() {
        guard !isContinueLoading else { return }
        guard let selectedMerchant, let itemQuote = currentMerchantQuote else { return }
        guard isInputWithinMinMaxLimit, canContinueToProvider else { return }

        let decimalAmount = NSDecimalNumber.fromBigUInt(value: inputAmount, decimals: inputDecimals).decimalValue
        let amountString = (decimalAmount as NSDecimalNumber).stringValue

        calculateTask?.cancel()
        calculateTask = nil
        invalidateQuoteRequest()
        isContinueLoading = true

        Task { @MainActor [weak self] in
            guard let self else { return }

            defer { isContinueLoading = false }

            do {
                let widgetURL: URL
                if quoteService.createsOrderOnContinue {
                    widgetURL = try await quoteService.resolveWidgetURL(
                        flow: flow,
                        amount: amountString,
                        currencyCode: currency.code,
                        paymentMethodType: paymentMethodContext.type,
                        merchantId: selectedMerchant.id,
                        merchantTransactionId: itemQuote.merchantTransactionId
                    )
                } else if let url = itemQuote.widgetURL {
                    widgetURL = url
                } else {
                    didShowError?(TKLocales.Errors.unknown)
                    return
                }

                logContinueAnalytics(decimalAmount: decimalAmount, providerName: selectedMerchant.title)

                didTapContinue?(
                    RampOnrampContinueContext(
                        amount: decimalAmount,
                        providerName: selectedMerchant.title,
                        txId: itemQuote.merchantTransactionId
                    ),
                    selectedMerchant,
                    widgetURL
                )
            } catch {
                didShowError?(TKLocales.Errors.unknown)
            }
        }
    }

    private func logContinueAnalytics(decimalAmount: Decimal, providerName: String) {
        switch flow {
        case .deposit:
            if let buyAsset = assetContext.depositAnalyticsAssetIdentifier.flatMap(DepositClickOnrampContinue.BuyAsset.init(rawValue:)) {
                analyticsProvider.log(
                    DepositClickOnrampContinue(
                        buyAsset: buyAsset,
                        providerName: providerName,
                        buyAmount: NSDecimalNumber(decimal: decimalAmount).floatValue
                    )
                )
            }
        case .withdraw:
            if let sellAsset = assetContext.withdrawAnalyticsAssetIdentifier.flatMap(WithdrawClickOnrampContinue.SellAsset.init(rawValue:)) {
                analyticsProvider.log(
                    WithdrawClickOnrampContinue(
                        sellAsset: sellAsset,
                        providerName: providerName,
                        sellAmount: NSDecimalNumber(decimal: decimalAmount).floatValue
                    )
                )
            }
        }
    }

    func didTapProviderView() {
        guard let selectedMerchant else { return }
        let items = buildProviderPickerItems()
        guard !items.isEmpty else { return }

        didTapProvider?(items, selectedMerchant)
    }

    @MainActor
    func setSelectedMerchant(_ merchant: OnRampMerchantInfo) {
        let previousMerchantId = selectedMerchant?.id
        selectedMerchant = merchant
        didUpdateProviderView?(providerViewState)
        updateAmountErrorAndContinueButton()
        manualProviderChange = true
        runCalculate()
        if previousMerchantId != merchant.id {
            logViewOnrampInsertAmount(for: merchant)
        }
    }

    func selectBestMerchant() {
        let candidates = selectableMerchants
        let merchant = bestMerchantId.flatMap { id in candidates.first { $0.id == id } }
            ?? candidates.first

        guard let merchant else {
            if selectedMerchant != nil {
                selectedMerchant = nil
                didUpdateProviderView?(providerViewState)
            }
            return
        }

        guard selectedMerchant != merchant else { return }

        selectedMerchant = merchant
        if hasNotifiedInitialMerchant {
            logViewOnrampInsertAmount(for: merchant)
        }
        didUpdateProviderView?(providerViewState)
    }

    func resyncSelectedMerchantWithSelectableMerchants() {
        if let selectedMerchant, selectableMerchants.contains(where: { $0.id == selectedMerchant.id }) {
            return
        }
        manualProviderChange = false
        selectBestMerchant()
    }

    @MainActor
    func updateAmountErrorAndContinueButton() {
        applyConvertedAmountRate()
        amountInputModuleInput.isConvertedAmountHidden = shouldHideConvertedAmount
        updateContinueButton()
        didUpdateProviderView?(providerViewState)
        didUpdateProviderViewHidden?(selectedMerchant == nil)
    }

    func updateContinueButton() {
        didUpdateButton?(continueButtonConfiguration)
    }

    func logViewOnrampInsertAmount(for merchant: OnRampMerchantInfo?) {
        switch flow {
        case .deposit:
            guard let buyAsset = assetContext.depositAnalyticsAssetIdentifier.flatMap(DepositViewOnrampInsertAmount.BuyAsset.init(rawValue:)) else {
                return
            }
            analyticsProvider.log(
                DepositViewOnrampInsertAmount(
                    buyAsset: buyAsset,
                    providerName: merchant?.title ?? ""
                )
            )
        case .withdraw:
            guard let sellAsset = assetContext.withdrawAnalyticsAssetIdentifier.flatMap(WithdrawViewOnrampInsertAmount.SellAsset.init(rawValue:)) else {
                return
            }
            analyticsProvider.log(
                WithdrawViewOnrampInsertAmount(
                    sellAsset: sellAsset,
                    providerName: merchant?.title ?? ""
                )
            )
        }
    }
}
