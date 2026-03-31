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

    // MARK: - View bindings

    var didUpdateTitle: ((String) -> Void)?
    var didUpdateButton: ((TKButton.Configuration) -> Void)?
    var didUpdateProviderView: ((InsertAmountProviderViewState) -> Void)?
    var didUpdateProviderViewHidden: ((Bool) -> Void)?
    var didUpdateAmountError: ((String?) -> Void)?
    var didShowError: ((String) -> Void)?

    @MainActor
    var isLoading = false {
        didSet {
            didUpdateProviderView?(providerViewState)
            amountInputModuleInput.isConvertedAmountHidden = shouldHideConvertedAmount
            amountInputModuleInput.isConvertedShimmering = isLoading
            didUpdateButton?(continueButtonConfiguration)
        }
    }

    // MARK: - Properties

    var amountInputEnabled = false

    var lastCalculateResult: OnRampCalculateResult?
    var lastCalculatedAmount: BigUInt?

    let flow: RampFlow
    let asset: RampAsset
    let paymentMethod: OnRampLayoutCashMethod
    let currency: RemoteCurrency
    let wallet: Wallet
    let processedBalanceStore: ProcessedBalanceStore
    let onRampService: OnRampService
    let amountInputModuleInput: AmountInputModuleInput
    let amountInputModuleOutput: AmountInputModuleOutput
    let amountFormatter: AmountFormatter
    private let analyticsProvider: AnalyticsProvider

    var inputAmount: BigUInt = 0
    var selectedMerchant: OnRampMerchantInfo?
    var availableMerchants: [OnRampMerchantInfo] = []

    var calculateTask: Task<Void, Never>?

    var calculatedRate: Decimal?

    var manualProviderChange: Bool = false
    var isInitialAmountLoading: Bool = false

    // MARK: - Init

    init(
        flow: RampFlow,
        asset: RampAsset,
        paymentMethod: OnRampLayoutCashMethod,
        currency: RemoteCurrency,
        wallet: Wallet,
        processedBalanceStore: ProcessedBalanceStore,
        onRampService: OnRampService,
        amountInputModuleInput: AmountInputModuleInput,
        amountInputModuleOutput: AmountInputModuleOutput,
        amountFormatter: AmountFormatter,
        analyticsProvider: AnalyticsProvider
    ) {
        self.flow = flow
        self.asset = asset
        self.paymentMethod = paymentMethod
        self.currency = currency
        self.wallet = wallet
        self.processedBalanceStore = processedBalanceStore
        self.onRampService = onRampService
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
        didUpdateAmountError?(nil)
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
        guard let selectedMerchant, let currentQuoteWidgetURL else { return }
        guard isInputWithinMinMaxLimit, canContinueToProvider else { return }

        let decimalAmount = NSDecimalNumber.fromBigUInt(value: inputAmount, decimals: inputDecimals).decimalValue
        switch flow {
        case .deposit:
            if let buyAsset = asset.depositAnalyticsAssetIdentifier.flatMap(DepositClickOnrampContinue.BuyAsset.init(rawValue:)) {
                analyticsProvider.log(
                    DepositClickOnrampContinue(
                        buyAsset: buyAsset,
                        providerName: selectedMerchant.title,
                        buyAmount: NSDecimalNumber(decimal: decimalAmount).floatValue
                    )
                )
            }
        case .withdraw:
            if let sellAsset = asset.withdrawAnalyticsAssetIdentifier.flatMap(WithdrawClickOnrampContinue.SellAsset.init(rawValue:)) {
                analyticsProvider.log(
                    WithdrawClickOnrampContinue(
                        sellAsset: sellAsset,
                        providerName: selectedMerchant.title,
                        sellAmount: NSDecimalNumber(decimal: decimalAmount).floatValue
                    )
                )
            }
        }

        didTapContinue?(
            RampOnrampContinueContext(
                amount: decimalAmount,
                providerName: selectedMerchant.title,
                txId: UUID() // TODO: tx_id handling
            ),
            selectedMerchant,
            currentQuoteWidgetURL
        )
    }

    func didTapProviderView() {
        guard let selectedMerchant, !availableMerchants.isEmpty else { return }

        didTapProvider?(buildProviderPickerItems(), selectedMerchant)
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
        if let merchant = availableMerchants.first(where: { $0.id == bestMerchantId }), selectedMerchant != merchant {
            selectedMerchant = merchant
            logViewOnrampInsertAmount(for: merchant)
            didUpdateProviderView?(providerViewState)
        }
    }

    @MainActor
    func updateAmountErrorAndContinueButton() {
        let error = amountValidationError()
        didUpdateAmountError?(error.map { err in
            switch err {
            case let .belowMin(msg), let .aboveMax(msg): return msg
            }
        })
        amountInputModuleInput.isConvertedAmountHidden = shouldHideConvertedAmount
        didUpdateButton?(continueButtonConfiguration)
        didUpdateProviderViewHidden?(error != nil || selectedMerchant == nil)
    }

    func logViewOnrampInsertAmount(for merchant: OnRampMerchantInfo?) {
        switch flow {
        case .deposit:
            guard let buyAsset = asset.depositAnalyticsAssetIdentifier.flatMap(DepositViewOnrampInsertAmount.BuyAsset.init(rawValue:)) else {
                return
            }
            analyticsProvider.log(
                DepositViewOnrampInsertAmount(
                    buyAsset: buyAsset,
                    providerName: merchant?.title ?? ""
                )
            )
        case .withdraw:
            guard let sellAsset = asset.withdrawAnalyticsAssetIdentifier.flatMap(WithdrawViewOnrampInsertAmount.SellAsset.init(rawValue:)) else {
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
