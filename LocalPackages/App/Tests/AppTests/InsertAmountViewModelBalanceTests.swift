@testable import App
import BigInt
@testable import KeeperCore
import TKCore
import TKUIKit
import TonSwift
import UIKit
import XCTest

@MainActor
final class InsertAmountViewModelBalanceTests: XCTestCase {
    private static let analyticsProvider: AnalyticsProvider = {
        let coreAssembly = CoreAssembly()
        return AnalyticsProvider(
            analyticsServices: [],
            uniqueIdProvider: coreAssembly.uniqueIdProvider,
            appInfoProvider: coreAssembly.appInfoProvider,
            keysCountryCodeProvider: coreAssembly.keysCountryCodeProvider
        )
    }()

    func test_setupAmountInput_withdrawMultichain_wiresAssetBalanceIntoInput() {
        let balance = BigUInt(379_000)
        let asset = makeMultichainAsset(balance: balance)
        let (viewModel, amountInput) = makeModule(flow: .withdraw, assetContext: .multichain(asset), assetUnit: asset)

        viewModel.setupAmountInput()

        XCTAssertEqual(amountInput.sourceBalance, balance)
        XCTAssertTrue(amountInput.isBalanceVisible)
        XCTAssertTrue(amountInput.isMaxButtonVisible)
    }

    func test_viewDidLoad_withdrawMultichain_doesNotFetchQuoteBeforeUserInput() async {
        let quoteService = QuoteServiceStub(merchants: [makeMerchant("merchant")])
        let asset = makeMultichainAsset(balance: 379_000)
        let (viewModel, _) = makeModule(
            flow: .withdraw,
            assetContext: .multichain(asset),
            assetUnit: asset,
            quoteService: quoteService
        )

        viewModel.viewDidLoad()

        await quoteService.waitForMerchantLoad()
        await settle()

        let quoteAmounts = await quoteService.recordedQuoteAmounts()
        XCTAssertEqual(viewModel.inputAmount, 0)
        XCTAssertTrue(quoteAmounts.isEmpty)
    }

    func test_withdrawMultichain_enablesAmountWithinBalanceAndBlocksAboveIt() {
        let asset = makeMultichainAsset(balance: 379_000)
        let (viewModel, amountInput) = makeModule(flow: .withdraw, assetContext: .multichain(asset), assetUnit: asset)

        viewModel.setupAmountInput()

        amountInput.didEditText("0.00379")
        XCTAssertTrue(amountInput.isEnable)

        amountInput.didEditText("0.0038")
        XCTAssertFalse(amountInput.isEnable)
    }

    func test_setupAmountInput_depositMultichain_keepsBalanceHidden() {
        let asset = makeMultichainAsset(balance: 379_000)
        let (viewModel, amountInput) = makeModule(flow: .deposit, assetContext: .multichain(asset), assetUnit: asset)
        amountInput.isMaxButtonVisible = true

        viewModel.setupAmountInput()

        XCTAssertEqual(amountInput.sourceBalance, 0)
        XCTAssertFalse(amountInput.isBalanceVisible)
        XCTAssertFalse(amountInput.isMaxButtonVisible)
    }

    func test_setupAmountInput_withdrawLegacy_withoutStoredBalance_leavesSourceBalanceUntouched() {
        let asset = makeLegacyAsset()
        let (viewModel, amountInput) = makeModule(flow: .withdraw, assetContext: .legacy(asset), assetUnit: asset)
        amountInput.sourceBalance = 7

        viewModel.setupAmountInput()

        XCTAssertEqual(amountInput.sourceBalance, 7)
    }

    func test_maxButton_afterClearingInput_setsBalance() {
        let balance = BigUInt(379_000)
        let asset = makeMultichainAsset(balance: balance)
        let (viewModel, amountInput) = makeModule(flow: .withdraw, assetContext: .multichain(asset), assetUnit: asset)

        var lastBalanceConfiguration: AmountInputBalanceView.Configuration?
        amountInput.didUpdateBalanceViewConfiguration = { lastBalanceConfiguration = $0 }
        var lastInputText: String?
        amountInput.didUpdateInputText = { lastInputText = $0 }

        viewModel.setupAmountInput()

        var lastSourceAmount: BigUInt?
        amountInput.didUpdateSourceAmount = { lastSourceAmount = $0 }

        amountInput.didEditText("0.00379")
        amountInput.didEditText("")
        XCTAssertEqual(lastSourceAmount, 0)

        lastBalanceConfiguration?.maxButtonConfiguration?.action?()

        XCTAssertEqual(lastSourceAmount, balance)
        XCTAssertEqual(lastInputText, "0.00379")
    }

    func test_maxButton_whenAtMax_togglesOff() {
        let balance = BigUInt(379_000)
        let asset = makeMultichainAsset(balance: balance)
        let (viewModel, amountInput) = makeModule(flow: .withdraw, assetContext: .multichain(asset), assetUnit: asset)

        var lastBalanceConfiguration: AmountInputBalanceView.Configuration?
        amountInput.didUpdateBalanceViewConfiguration = { lastBalanceConfiguration = $0 }
        var lastInputText: String?
        amountInput.didUpdateInputText = { lastInputText = $0 }

        viewModel.setupAmountInput()

        var lastSourceAmount: BigUInt?
        amountInput.didUpdateSourceAmount = { lastSourceAmount = $0 }

        lastBalanceConfiguration?.maxButtonConfiguration?.action?()
        XCTAssertEqual(lastSourceAmount, balance)
        XCTAssertEqual(lastInputText, "0.00379")

        lastBalanceConfiguration?.maxButtonConfiguration?.action?()
        XCTAssertEqual(lastSourceAmount, 0)
        XCTAssertEqual(lastInputText, "")
    }

    func test_maxButton_withZeroBalance_doesNotWipeInput() {
        let asset = makeMultichainAsset(balance: 0)
        let (viewModel, amountInput) = makeModule(flow: .withdraw, assetContext: .multichain(asset), assetUnit: asset)

        var lastBalanceConfiguration: AmountInputBalanceView.Configuration?
        amountInput.didUpdateBalanceViewConfiguration = { lastBalanceConfiguration = $0 }

        viewModel.setupAmountInput()

        var lastSourceAmount: BigUInt?
        amountInput.didUpdateSourceAmount = { lastSourceAmount = $0 }

        amountInput.didEditText("0.00379")
        XCTAssertEqual(lastSourceAmount, BigUInt(379_000))

        lastBalanceConfiguration?.maxButtonConfiguration?.action?()

        XCTAssertEqual(lastSourceAmount, BigUInt(379_000))
    }

    func test_bestMerchant_prefersFirstServiceableInServerOrder() {
        let viewModel = makeDepositModule()
        viewModel.availableMerchants = [makeMerchant("A"), makeMerchant("B"), makeMerchant("C")]
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [makeQuote("A", min: 100), makeQuote("B", min: 5, rate: 2, converted: 20), makeQuote("C", min: 5)],
            suggestedQuotes: []
        )
        viewModel.inputAmount = 1000 // $10.00 at 2 fraction digits

        XCTAssertEqual(viewModel.bestMerchantId, "B")

        viewModel.selectBestMerchant()
        XCTAssertEqual(viewModel.selectedMerchant?.id, "B")
    }

    func test_didPerformQuote_onInitialLoad_selectsBestProvider() {
        let viewModel = makeDepositModule()
        let mercuryo = makeMerchant("mercuryo")
        let moonpay = makeMerchant("moonpay")
        viewModel.availableMerchants = [mercuryo, moonpay]
        viewModel.selectedMerchant = mercuryo
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [
                makeQuote("moonpay", min: 5, rate: 0.0000151, converted: 0.000453),
                makeQuote("mercuryo", min: 5, rate: 0.0000146, converted: 0.000438),
            ],
            suggestedQuotes: []
        )
        viewModel.inputAmount = 3000
        viewModel.lastCalculatedAmount = 3000

        viewModel.didPerformQuote(isInitialLoading: true)

        XCTAssertEqual(viewModel.selectedMerchant?.id, "moonpay")
        XCTAssertEqual(viewModel.bestMerchantId, "moonpay")
    }

    func test_belowAllMin_selectsClosest_showsOrangeWarning_disablesContinue_keepsCellVisible() throws {
        let viewModel = makeDepositModule()
        viewModel.availableMerchants = [makeMerchant("A"), makeMerchant("B")]
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [makeQuote("A", min: 50), makeQuote("B", min: 20)],
            suggestedQuotes: []
        )
        viewModel.inputAmount = 1000 // $10.00, below both mins

        XCTAssertFalse(viewModel.hasServiceableMerchant)
        XCTAssertEqual(viewModel.closestBelowMinMerchantId, "B") // smallest min above input

        var lastHidden: Bool?
        viewModel.didUpdateProviderViewHidden = { lastHidden = $0 }

        viewModel.selectBestMerchant()
        viewModel.updateAmountErrorAndContinueButton()

        XCTAssertEqual(viewModel.selectedMerchant?.id, "B")
        XCTAssertFalse(viewModel.isInputWithinMinMaxLimit)
        XCTAssertEqual(lastHidden, false)

        let caption = try XCTUnwrap(
            viewModel.providerConfiguration.textContentViewConfiguration.captionViewsConfigurations.first
        )
        let attributed = try XCTUnwrap(caption.text)
        XCTAssertEqual(attributed.string, viewModel.minAmountText(for: "B"))
        let color = attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, .Accent.orange)
    }

    func test_providerPickerItems_belowMinProvider_showsLimitAndSuppressesRate() {
        let viewModel = makeDepositModule()
        viewModel.availableMerchants = [makeMerchant("A"), makeMerchant("B")]
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [makeQuote("A", min: 50, rate: 2, converted: 20), makeQuote("B", min: 20)],
            suggestedQuotes: []
        )
        viewModel.inputAmount = 1000 // below both mins

        let items = viewModel.buildProviderPickerItems()
        let itemA = items.first { $0.merchant.id == "A" }
        XCTAssertNotNil(itemA?.amountLimitText)
        XCTAssertNil(itemA?.rateText) // rate suppressed while a limit warning is shown
    }

    func test_providerPickerItems_hidesProvidersMissingFromQuoteResponse() {
        let viewModel = makeDepositModule()
        viewModel.availableMerchants = [makeMerchant("mercuryo"), makeMerchant("moonpay")]
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [makeQuote("mercuryo", min: 5, rate: 0.944, converted: 28.32)],
            suggestedQuotes: []
        )
        viewModel.inputAmount = 3000 // $30.00

        let items = viewModel.buildProviderPickerItems()
        XCTAssertEqual(items.map(\.merchant.id), ["mercuryo"])
    }

    func test_providerPickerItems_preserveServerQuoteOrder() {
        let viewModel = makeDepositModule()
        viewModel.availableMerchants = [makeMerchant("mercuryo"), makeMerchant("moonpay")]
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [
                makeQuote("moonpay", min: 5, rate: 0.0000151, converted: 0.000453),
                makeQuote("mercuryo", min: 5, rate: 0.0000146, converted: 0.000438),
            ],
            suggestedQuotes: []
        )
        viewModel.inputAmount = 3000

        let items = viewModel.buildProviderPickerItems()
        XCTAssertEqual(items.map(\.merchant.id), ["moonpay", "mercuryo"])
        XCTAssertEqual(viewModel.bestMerchantId, "moonpay")
        XCTAssertTrue(items[0].best)
        XCTAssertFalse(items[1].best)
    }

    func test_selectedMerchantWithoutQuote_isReplacedByQuotedMerchant() {
        let viewModel = makeDepositModule()
        let mercuryo = makeMerchant("mercuryo")
        let moonpay = makeMerchant("moonpay")
        viewModel.availableMerchants = [mercuryo, moonpay]
        viewModel.selectedMerchant = moonpay
        viewModel.manualProviderChange = true
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [makeQuote("mercuryo", min: 5, rate: 0.944, converted: 28.32)],
            suggestedQuotes: []
        )
        viewModel.inputAmount = 3000

        viewModel.resyncSelectedMerchantWithSelectableMerchants()

        XCTAssertEqual(viewModel.selectedMerchant?.id, "mercuryo")
        XCTAssertEqual(viewModel.buildProviderPickerItems().map(\.merchant.id), ["mercuryo"])
    }

    func test_closestBelowMin_ignoresMerchantsMissingFromQuotes() {
        let viewModel = makeDepositModule()
        let quoted = makeMerchant("quoted")
        let layoutOnly = makeMerchant("layoutOnly")
        viewModel.availableMerchants = [quoted, layoutOnly]
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [makeQuote("quoted", min: 50)],
            suggestedQuotes: []
        )
        viewModel.inputAmount = 1000 // $10

        XCTAssertEqual(viewModel.closestBelowMinMerchantId, "quoted")
        viewModel.selectBestMerchant()
        XCTAssertEqual(viewModel.selectedMerchant?.id, "quoted")
    }

    func test_withoutQuotesState_pickerUsesAllAvailableMerchants() {
        let viewModel = makeDepositModule()
        viewModel.availableMerchants = [makeMerchant("A"), makeMerchant("B")]
        viewModel.lastQuotesState = nil
        viewModel.inputAmount = 0

        XCTAssertEqual(viewModel.buildProviderPickerItems().map(\.merchant.id), ["A", "B"])
    }

    func test_zeroAmount_doesNotShowLimitWarning() {
        let viewModel = makeDepositModule()
        let merchant = makeMerchant("A")
        viewModel.availableMerchants = [merchant]
        viewModel.selectedMerchant = merchant
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [makeQuote("A", min: 20)],
            suggestedQuotes: []
        )
        viewModel.inputAmount = 0

        XCTAssertNil(viewModel.minAmountText(for: "A"))
        XCTAssertTrue(
            viewModel.providerConfiguration
                .textContentViewConfiguration
                .captionViewsConfigurations
                .isEmpty
        )
    }

    func test_amountChangeBelowAllMinimums_selectsClosestMerchantImmediately() {
        let (viewModel, amountInput) = makeDepositModuleWithInput()
        let merchantA = makeMerchant("A")
        let merchantB = makeMerchant("B")
        viewModel.availableMerchants = [merchantA, merchantB]
        viewModel.selectedMerchant = merchantA
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [makeQuote("A", min: 50), makeQuote("B", min: 20)],
            suggestedQuotes: []
        )
        viewModel.setupAmountInput()

        amountInput.didEditText("10")

        XCTAssertEqual(viewModel.selectedMerchant?.id, "B")
    }

    func test_emptyQuotesState_stillHasServiceableMerchantForFetch() {
        let viewModel = makeDepositModule()
        viewModel.availableMerchants = [makeMerchant("A"), makeMerchant("B")]
        // Empty response leaves lastQuotesState non-nil; selectable list is empty but fetch
        // must still be allowed for later amount edits.
        viewModel.lastQuotesState = InsertAmountQuotesState(quotes: [], suggestedQuotes: [])
        viewModel.inputAmount = 3000

        XCTAssertTrue(viewModel.selectableMerchants.isEmpty)
        XCTAssertTrue(viewModel.hasServiceableMerchant)
    }

    func test_staleQuoteFailureDoesNotStopCurrentLoadingOrShowError() async {
        let quoteService = SuspendedQuoteService()
        let asset = makeLegacyAsset()
        let (viewModel, _) = makeModule(
            flow: .deposit,
            assetContext: .legacy(asset),
            assetUnit: asset,
            quoteService: quoteService
        )
        let merchant = makeMerchant("merchant")
        viewModel.availableMerchants = [merchant]
        viewModel.selectedMerchant = merchant
        var errors = [String]()
        viewModel.didShowError = { errors.append($0) }

        viewModel.inputAmount = 100
        viewModel.runCalculate()
        await quoteService.waitForRequestCount(1)

        viewModel.inputAmount = 200
        viewModel.runCalculate()
        await quoteService.waitForRequestCount(2)

        quoteService.failRequest(at: 0)
        await settle()

        XCTAssertTrue(viewModel.isLoading)
        XCTAssertTrue(errors.isEmpty)

        quoteService.completeRequest(at: 1)
        await settle()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(errors.isEmpty)
    }

    func test_withdrawMultichain_belowProviderMin_keepsConvertedAmountAtMarketRate() {
        let asset = makeMultichainAsset(balance: 379_000, prices: ["usd": 100_000])
        let (viewModel, amountInput) = makeModule(flow: .withdraw, assetContext: .multichain(asset), assetUnit: asset)

        viewModel.setupAmountInput()
        viewModel.availableMerchants = [makeMerchant("A")]
        viewModel.selectedMerchant = viewModel.availableMerchants.first
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [],
            suggestedQuotes: [makeQuote("A", min: 0.005, rate: 62000, converted: 310)]
        )

        var lastValueConfiguration: AmountInputValueView.Configuration?
        amountInput.didUpdateValueViewConfiguration = { lastValueConfiguration = $0 }

        amountInput.didEditText("0.001") // below the 0.005 min

        XCTAssertNotNil(viewModel.minAmountText(for: "A"))
        XCTAssertFalse(viewModel.shouldHideConvertedAmount)
        XCTAssertFalse(amountInput.isConvertedAmountHidden)
        XCTAssertEqual(amountInput.rate, NSDecimalNumber(value: 100_000))
        XCTAssertEqual(lastValueConfiguration?.convertedButtonConfiguration.text, "100")
    }

    func test_withdrawMultichain_withinProviderLimits_prefersQuoteRateOverMarketPrice() {
        let asset = makeMultichainAsset(balance: 100_000_000, prices: ["usd": 100_000])
        let (viewModel, amountInput) = makeModule(flow: .withdraw, assetContext: .multichain(asset), assetUnit: asset)

        viewModel.setupAmountInput()
        viewModel.availableMerchants = [makeMerchant("A")]
        viewModel.selectedMerchant = viewModel.availableMerchants.first
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [makeQuote("A", min: 0.005, rate: 62000, converted: 620)],
            suggestedQuotes: []
        )

        var lastValueConfiguration: AmountInputValueView.Configuration?
        amountInput.didUpdateValueViewConfiguration = { lastValueConfiguration = $0 }

        amountInput.didEditText("0.01") // above the 0.005 min

        XCTAssertNil(viewModel.minAmountText(for: "A"))
        XCTAssertFalse(amountInput.isConvertedAmountHidden)
        XCTAssertEqual(amountInput.rate, NSDecimalNumber(value: 62000))
        XCTAssertEqual(lastValueConfiguration?.convertedButtonConfiguration.text, "620")
    }

    func test_withdrawLegacy_belowProviderMin_withoutMarketPrice_hidesConvertedAmount() {
        let asset = makeLegacyAsset()
        let (viewModel, amountInput) = makeModule(flow: .withdraw, assetContext: .legacy(asset), assetUnit: asset)

        viewModel.setupAmountInput()
        viewModel.availableMerchants = [makeMerchant("A")]
        viewModel.selectedMerchant = viewModel.availableMerchants.first
        viewModel.lastQuotesState = InsertAmountQuotesState(
            quotes: [],
            suggestedQuotes: [makeQuote("A", min: 50, rate: 3, converted: 150)]
        )
        viewModel.inputAmount = 1_000_000_000 // 1 TON, below the 50 min

        viewModel.updateAmountErrorAndContinueButton()

        XCTAssertTrue(viewModel.shouldHideConvertedAmount)
        XCTAssertTrue(amountInput.isConvertedAmountHidden)
    }
}

private extension InsertAmountViewModelBalanceTests {
    func makeModule(
        flow: RampFlow,
        assetContext: InsertAmountAssetContext,
        assetUnit: any AmountInputUnit,
        quoteService: any InsertAmountQuoteServicing = QuoteServiceStub()
    ) -> (InsertAmountViewModel, AmountInputViewModelImplementation) {
        let currency = RemoteCurrency(
            code: "USD",
            name: "United States Dollar",
            image: "",
            type: "fiat"
        )
        let amountFormatter = makeAmountFormatter()

        let (sourceUnit, destinationUnit): (any AmountInputUnit, any AmountInputUnit) = switch flow {
        case .deposit: (currency, assetUnit)
        case .withdraw: (assetUnit, currency)
        }
        let amountInput = AmountInputViewModelImplementation(
            amountFormatter: amountFormatter,
            sourceUnit: sourceUnit,
            destinationUnit: destinationUnit
        )

        let paymentMethod = OnRampPaymentMethod(
            type: "card",
            name: "Card",
            image: "",
            isP2P: false,
            providers: []
        )

        let viewModel = InsertAmountViewModel(
            flow: flow,
            assetContext: assetContext,
            paymentMethodContext: InsertAmountPaymentMethodContext(paymentMethod, currencyCode: currency.code),
            currency: currency,
            wallet: makeWallet(),
            processedBalanceStore: makeProcessedBalanceStore(),
            quoteService: quoteService,
            amountInputModuleInput: amountInput,
            amountInputModuleOutput: amountInput,
            amountFormatter: amountFormatter,
            analyticsProvider: Self.analyticsProvider
        )

        return (viewModel, amountInput)
    }

    func makeDepositModule() -> InsertAmountViewModel {
        makeDepositModuleWithInput().0
    }

    func makeDepositModuleWithInput() -> (InsertAmountViewModel, AmountInputViewModelImplementation) {
        let asset = makeLegacyAsset()
        return makeModule(flow: .deposit, assetContext: .legacy(asset), assetUnit: asset)
    }

    func makeMerchant(_ id: String) -> OnRampMerchantInfo {
        OnRampMerchantInfo(id: id, title: id, description: "", image: "", fee: 0, isP2P: false, buttons: [])
    }

    func makeQuote(
        _ id: String,
        min: Double?,
        max: Double? = nil,
        rate: Decimal? = nil,
        converted: Decimal = 1
    ) -> InsertAmountMerchantQuote {
        InsertAmountMerchantQuote(
            merchantId: id,
            merchantTransactionId: "tx-\(id)",
            convertedAmount: converted,
            amountIn: nil,
            rate: rate,
            minAmount: min,
            maxAmount: max,
            widgetURL: nil
        )
    }

    func makeMultichainAsset(balance: BigUInt, prices: [String: Double] = [:]) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: "btc/mainnet/coin",
                name: "Bitcoin",
                symbol: "BTC",
                decimals: 8,
                image: ""
            ),
            price: MultichainAssetPrice(
                prices: prices,
                diff24h: [:],
                diff7d: [:],
                diff30d: [:]
            ),
            balance: balance
        )
    }

    func makeLegacyAsset() -> RampAsset {
        OnRampLayoutToken(
            symbol: "TON",
            assetId: "ton",
            address: nil,
            network: "ton",
            networkName: "The Open Network",
            networkImage: "",
            image: "",
            decimals: 9,
            stablecoin: false,
            cashMethods: [],
            cryptoMethods: []
        )
    }

    func makeWallet() -> Wallet {
        let publicKey = PublicKey(data: Data(repeating: 0x01, count: 32))
        return Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings()
        )
    }

    func makeAmountFormatter() -> AmountFormatter {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return AmountFormatter(configuration: configuration)
    }

    func makeProcessedBalanceStore() -> ProcessedBalanceStore {
        let keeperInfoStore = KeeperInfoStore(keeperInfoRepository: KeeperInfoRepositoryStub())
        let walletsStore = WalletsStore(keeperInfoStore: keeperInfoStore)
        return ProcessedBalanceStore(
            walletsStore: walletsStore,
            balanceStore: BalanceStore(walletsStore: walletsStore, repository: WalletBalanceRepositoryStub()),
            tonRatesStore: TonRatesStore(repository: RatesRepositoryStub()),
            currencyStore: CurrencyStore(keeperInfoStore: keeperInfoStore),
            stakingPoolsStore: StakingPoolsStore(walletsStore: walletsStore, repository: StakingPoolsInfoRepositoryStub())
        )
    }

    func settle() async {
        for _ in 0 ..< 16 {
            await Task.yield()
        }
    }
}

private struct StubError: Error {}

private actor QuoteServiceStub: InsertAmountQuoteServicing {
    nonisolated var createsOrderOnContinue: Bool {
        true
    }

    private let merchants: [OnRampMerchantInfo]
    private var didLoadMerchants = false
    private var quoteAmounts = [String]()

    init(merchants: [OnRampMerchantInfo] = []) {
        self.merchants = merchants
    }

    func loadMerchants(providerIds _: [String]) async throws -> [OnRampMerchantInfo] {
        didLoadMerchants = true
        return merchants
    }

    func fetchQuotes(
        flow _: RampFlow,
        amount: String,
        currencyCode _: String,
        paymentMethodType _: String,
        merchantId _: String?
    ) async throws -> InsertAmountQuotesState {
        quoteAmounts.append(amount)
        return InsertAmountQuotesState(quotes: [], suggestedQuotes: [])
    }

    func resolveWidgetURL(
        flow _: RampFlow,
        amount _: String,
        currencyCode _: String,
        paymentMethodType _: String,
        merchantId _: String,
        merchantTransactionId _: String
    ) async throws -> URL {
        throw StubError()
    }

    func waitForMerchantLoad() async {
        while !didLoadMerchants {
            await Task.yield()
        }
    }

    func recordedQuoteAmounts() -> [String] {
        quoteAmounts
    }
}

private final class SuspendedQuoteService: InsertAmountQuoteServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations = [CheckedContinuation<InsertAmountQuotesState, any Error>?]()

    var createsOrderOnContinue: Bool {
        true
    }

    func loadMerchants(providerIds _: [String]) async throws -> [OnRampMerchantInfo] {
        []
    }

    func fetchQuotes(
        flow _: RampFlow,
        amount _: String,
        currencyCode _: String,
        paymentMethodType _: String,
        merchantId _: String?
    ) async throws -> InsertAmountQuotesState {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                continuations.append(continuation)
            }
        }
    }

    func resolveWidgetURL(
        flow _: RampFlow,
        amount _: String,
        currencyCode _: String,
        paymentMethodType _: String,
        merchantId _: String,
        merchantTransactionId _: String
    ) async throws -> URL {
        throw StubError()
    }

    func waitForRequestCount(_ count: Int) async {
        while lock.withLock({ continuations.count }) < count {
            await Task.yield()
        }
    }

    func failRequest(at index: Int) {
        takeContinuation(at: index)?.resume(throwing: StubError())
    }

    func completeRequest(at index: Int) {
        takeContinuation(at: index)?.resume(
            returning: InsertAmountQuotesState(quotes: [], suggestedQuotes: [])
        )
    }

    private func takeContinuation(
        at index: Int
    ) -> CheckedContinuation<InsertAmountQuotesState, any Error>? {
        lock.withLock {
            guard continuations.indices.contains(index) else { return nil }
            defer { continuations[index] = nil }
            return continuations[index]
        }
    }
}

private struct KeeperInfoRepositoryStub: KeeperInfoRepository {
    func getKeeperInfo() throws -> KeeperInfo {
        throw StubError()
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}
    func removeKeeperInfo() throws {}
}

private struct WalletBalanceRepositoryStub: WalletBalanceRepositoryV2 {
    func getBalance(address _: FriendlyAddress) throws -> KeeperCore.WalletBalance {
        throw StubError()
    }
}

private struct RatesRepositoryStub: RatesRepository {
    func saveRates(_: Rates) throws {}

    func getRates() throws -> Rates {
        throw StubError()
    }
}

private struct StakingPoolsInfoRepositoryStub: StakingPoolsInfoRepository {
    func getStakingPoolsInfo(wallet _: Wallet) -> [StackingPoolInfo] {
        []
    }

    func setStakingPoolsInfo(_: [StackingPoolInfo], wallet _: Wallet) throws {}
}
