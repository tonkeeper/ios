import BigInt
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import TronSwift
import UIKit

@MainActor
final class WalletMigrationConfirmationViewModel: ObservableObject {
    enum ConfirmationState: Equatable {
        case idle
        case confirming
        case success
        case failed
        case retry
    }

    struct InsufficientFeeAmounts: Equatable {
        let required: UInt64
        let available: UInt64
    }

    enum Failure: Equatable {
        case generic
        case insufficientTonSoft(InsufficientFeeAmounts)
        case insufficientTrxSoft(InsufficientFeeAmounts)
        case insufficientFees(
            ton: InsufficientFeeAmounts,
            trx: InsufficientFeeAmounts
        )
    }

    enum State: Equatable {
        case loading
        case ready
        case failed(Failure)
    }

    struct ConfirmPayload {
        let ton: WalletMigrationPrepareResult?
        let tron: WalletMigrationTronPrepareResult?
        let sendTon: Bool
        let sendTron: Bool
        let tonFeeMethod: WalletMigrationPrepareResult.FeeMethod?
        let tronFeeMethod: WalletMigrationTronPrepareResult.FeeMethod?
    }

    struct FeeRowModel: Equatable {
        let title: String
        let value: String
        let method: String
        let canPickMethod: Bool
    }

    @Published private(set) var items: [TransactionCellContent] = []
    @Published private(set) var totalSummary: String = ""
    @Published private(set) var state: State = .loading
    @Published private(set) var confirmationState: ConfirmationState = .idle
    @Published private(set) var preparedResult: WalletMigrationPrepareResult?
    @Published private(set) var preparedTronResult: WalletMigrationTronPrepareResult?
    @Published private(set) var sendTon = false
    @Published private(set) var sendTron = false
    @Published private(set) var selectedTonFeeMethod: WalletMigrationPrepareResult.FeeMethod?
    @Published private(set) var selectedTronFeeMethod: WalletMigrationTronPrepareResult.FeeMethod?
    @Published private(set) var tonFeeRowModel: FeeRowModel?
    @Published private(set) var tronFeeRowModel: FeeRowModel?

    let destinationWalletName: String

    private let sourceWallet: Wallet
    private let destinationWallet: Wallet
    private let walletMigrationService: WalletMigrationService
    private let nftService: NFTService
    private let amountFormatter: AmountFormatter
    private let currencyStore: CurrencyStore
    private let appSettingsStore: AppSettingsStore
    private let walletNFTsRepository: WalletNFTsRepository
    private let ratesService: RatesService
    private let tonRatesStore: TonRatesStore
    private let analyticsProvider: AnalyticsProvider

    private var hasLoggedConfirmationView = false

    private var pendingTonResult: WalletMigrationPrepareResult?
    private var pendingTronResult: WalletMigrationTronPrepareResult?
    private var pendingTonFee: InsufficientFeeAmounts?
    private var pendingTrxFee: InsufficientFeeAmounts?
    private var loadedNFTs: [TonSwift.Address: NFT] = [:]
    private var tonRate: Rates.Rate?
    private var usdtRate: Rates.Rate?
    private var trxRate: Rates.Rate?
    private var availableBatteryCharges: Int?
    private var preparationID: UUID?
    private var confirmTask: Task<Void, Never>?

    private let onBack: () -> Void
    private let onClose: () -> Void
    private let onDepositTon: (_ onClose: @escaping () -> Void) -> Void
    private let onDepositTrx: (_ onClose: @escaping () -> Void) -> Void
    private let onDepositWallet: (_ onClose: @escaping () -> Void) -> Void
    private let onRefillBattery: (_ onRechargeSuccess: @escaping () -> Void) -> Void
    private let onPresentInsufficientFee: (InsufficientFeePopupContent) -> Void
    private let onConfirm: (ConfirmPayload) async throws -> Void
    private let onOpenFeePicker: (NetworkFeePickerPresentation) -> Void
    private let onShowMigrationInfo: () -> Void
    private let onSuccess: () -> Void

    init(
        sourceWallet: Wallet,
        destinationWallet: Wallet,
        walletMigrationService: WalletMigrationService,
        nftService: NFTService,
        amountFormatter: AmountFormatter,
        currencyStore: CurrencyStore,
        appSettingsStore: AppSettingsStore,
        walletNFTsRepository: WalletNFTsRepository,
        ratesService: RatesService,
        tonRatesStore: TonRatesStore,
        analyticsProvider: AnalyticsProvider,
        onBack: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {},
        onDepositTon: @escaping (_ onClose: @escaping () -> Void) -> Void = { _ in },
        onDepositTrx: @escaping (_ onClose: @escaping () -> Void) -> Void = { _ in },
        onDepositWallet: @escaping (_ onClose: @escaping () -> Void) -> Void = { _ in },
        onRefillBattery: @escaping (_ onRechargeSuccess: @escaping () -> Void) -> Void = { _ in },
        onPresentInsufficientFee: @escaping (InsufficientFeePopupContent) -> Void = { _ in },
        onConfirm: @escaping (ConfirmPayload) async throws -> Void = { _ in },
        onOpenFeePicker: @escaping (NetworkFeePickerPresentation) -> Void = { _ in },
        onShowMigrationInfo: @escaping () -> Void = {},
        onSuccess: @escaping () -> Void = {}
    ) {
        self.sourceWallet = sourceWallet
        self.destinationWallet = destinationWallet
        self.walletMigrationService = walletMigrationService
        self.nftService = nftService
        self.amountFormatter = amountFormatter
        self.currencyStore = currencyStore
        self.appSettingsStore = appSettingsStore
        self.walletNFTsRepository = walletNFTsRepository
        self.ratesService = ratesService
        self.tonRatesStore = tonRatesStore
        self.analyticsProvider = analyticsProvider
        self.destinationWalletName = destinationWallet.label
        self.onBack = onBack
        self.onClose = onClose
        self.onDepositTon = onDepositTon
        self.onDepositTrx = onDepositTrx
        self.onDepositWallet = onDepositWallet
        self.onRefillBattery = onRefillBattery
        self.onPresentInsufficientFee = onPresentInsufficientFee
        self.onConfirm = onConfirm
        self.onOpenFeePicker = onOpenFeePicker
        self.onShowMigrationInfo = onShowMigrationInfo
        self.onSuccess = onSuccess
    }

    var showsContinueOnFailure: Bool {
        switch state {
        case let .failed(failure):
            switch failure {
            case .insufficientTonSoft:
                return pendingTronResult != nil
            case .insufficientTrxSoft:
                return pendingTonResult?.hasExecutableTransactions == true
            case .generic, .insufficientFees:
                return false
            }
        default:
            return false
        }
    }

    func failurePlaceholderConfig() -> PlaceholderView.Config? {
        guard case .failed(.generic) = state else { return nil }

        return PlaceholderView.Config(
            lottieResource: .exclamationmarkCircle,
            title: TKLocales.Trade.Placeholder.errorTitle,
            subtitle: TKLocales.Trade.Placeholder.errorSubtitle,
            button: PlaceholderView.ButtonConfig(
                title: TKLocales.Actions.retry,
                icon: .TKUIKit.Icons.Size16.refresh,
                action: { [weak self] in
                    Task { await self?.retry() }
                }
            )
        )
    }

    func depositForInsufficientFee() {
        guard case let .failed(failure) = state else { return }
        switch failure {
        case .insufficientTonSoft:
            requestTonDeposit()
        case .insufficientTrxSoft:
            requestTrxDeposit()
        case .insufficientFees:
            requestWalletDeposit()
        case .generic:
            break
        }
    }

    var screenTitle: String {
        TKLocales.ConfirmSend.TokenTransfer.title
    }

    var screenSubtitle: String {
        destinationWalletName
    }

    var canStartConfirm: Bool {
        state == .ready
            && (sendTon || sendTron)
            && !items.isEmpty
            && (!sendTon || selectedTonFeeMethod != nil || preparedResult?.availableFeeMethods.isEmpty == true)
            && (!sendTron || selectedTronFeeMethod != nil || preparedTronResult?.availableFeeMethods.isEmpty == true)
            && !isSelectedFeeInsufficient
            && (confirmationState == .idle || confirmationState == .retry)
    }

    var isSliderEnabled: Bool {
        canStartConfirm && confirmationState == .idle
    }

    var processState: TKProcessContainerView.State {
        switch confirmationState {
        case .idle, .retry: .idle
        case .confirming: .process
        case .success: .success
        case .failed: .failed
        }
    }

    var sliderConfirmTitle: NSAttributedString {
        let title = NSMutableAttributedString()
        title.append(
            TKLocales.Actions.Confirm.title.withTextStyle(
                .label2,
                color: .Text.secondary,
                alignment: .center
            )
        )
        title.append(
            ("\n" + TKLocales.Actions.Confirm.subtitle).withTextStyle(
                .body3,
                color: .Text.tertiary,
                alignment: .center
            )
        )
        return title
    }

    func start() async {
        switch confirmationState {
        case .confirming, .success, .failed, .retry:
            return
        case .idle:
            confirmTask?.cancel()
            confirmTask = nil
        }

        let preparationID = UUID()
        self.preparationID = preparationID

        state = .loading
        items = []
        totalSummary = ""
        preparedResult = nil
        preparedTronResult = nil
        sendTon = false
        sendTron = false
        selectedTonFeeMethod = nil
        selectedTronFeeMethod = nil
        tonFeeRowModel = nil
        tronFeeRowModel = nil
        tonRate = nil
        usdtRate = nil
        trxRate = nil
        availableBatteryCharges = nil
        loadedNFTs = [:]
        pendingTonResult = nil
        pendingTronResult = nil
        pendingTonFee = nil
        pendingTrxFee = nil

        async let tonTask: Result<WalletMigrationPrepareResult, Error> = {
            do {
                let result = try await walletMigrationService.prepareMigration(
                    from: sourceWallet,
                    to: destinationWallet,
                    currency: currencyStore.state
                )
                return .success(result)
            } catch {
                return .failure(error)
            }
        }()

        async let tronTask: Result<WalletMigrationTronPrepareResult?, Error> = {
            do {
                let result = try await walletMigrationService.prepareTronMigration(
                    from: sourceWallet,
                    to: destinationWallet
                )
                return .success(result)
            } catch {
                return .failure(error)
            }
        }()

        async let batteryChargesTask = walletMigrationService.availableBatteryCharges(
            wallet: sourceWallet
        )

        let tonOutcome = await tonTask
        let tronOutcome = await tronTask
        let availableBatteryCharges = await batteryChargesTask

        guard isCurrentPreparation(preparationID) else { return }
        self.availableBatteryCharges = availableBatteryCharges

        var tonResult: WalletMigrationPrepareResult?
        var tronResult: WalletMigrationTronPrepareResult?
        var tonFee: InsufficientFeeAmounts?
        var trxFee: InsufficientFeeAmounts?
        var tonHardError = false
        var tronHardError = false
        var tonPrepareError: Error?
        var tronPrepareError: Error?

        defer {
            if isCurrentPreparation(preparationID) {
                logPrepareFailure(tonPrepareError, chain: .ton)
                logPrepareFailure(tronPrepareError, chain: .tron)
            }
        }

        switch tonOutcome {
        case let .success(result):
            tonResult = result
        case let .failure(error as WalletMigrationError):
            tonPrepareError = error
            if case let .insufficientTonForGas(required, available) = error {
                tonFee = .init(required: required, available: available)
            } else {
                tonHardError = true
            }
        case let .failure(error):
            tonPrepareError = error
            tonHardError = true
        }

        switch tronOutcome {
        case let .success(result):
            tronResult = result
        case let .failure(error as WalletMigrationError):
            tronPrepareError = error
            switch error {
            case let .insufficientTrxForFees(required, available):
                trxFee = .init(required: required, available: available)
            case .inactiveTronAccount:
                tronHardError = true
            case .insufficientTonForGas:
                tronHardError = true
            }
        case let .failure(error):
            tronPrepareError = error
            tronResult = nil
            tronHardError = true
        }

        if let ton = tonResult,
           let required = ton.requiredTonNano,
           let available = ton.availableTonNano,
           !WalletMigrationFeeSelectionResolver.hasPayableTonMethod(
               ton: ton,
               availableBatteryCharges: availableBatteryCharges
           )
        {
            tonFee = .init(required: required, available: available)
        }

        if tonHardError || tronHardError {
            state = .failed(.generic)
            return
        }

        let hasTon = tonResult?.hasExecutableTransactions == true
        let hasTron = tronResult != nil

        if tonFee == nil, let ton = tonResult {
            tonFee = tonShortage(ton: ton, availableBatteryCharges: availableBatteryCharges)
        }

        if trxFee == nil, hasTron, let tron = tronResult {
            // An unpayable TON leg will not ride along (it ends in deposit or a TON-only skip),
            // so it must not poison the TRON pairing check with its own insufficiency.
            trxFee = trxShortage(
                tron: tron,
                ton: hasTon && tonFee == nil ? tonResult : nil,
                availableBatteryCharges: availableBatteryCharges
            )
        }

        pendingTonResult = tonResult
        pendingTronResult = tronResult
        pendingTonFee = tonFee
        pendingTrxFee = trxFee

        if let tonFee, let trxFee {
            presentInsufficientFee(.insufficientFees(ton: tonFee, trx: trxFee))
            return
        }

        if let tonFee, hasTron || !offersBatteryFeeMethod(tonResult) {
            presentInsufficientFee(.insufficientTonSoft(tonFee))
            return
        }

        if let trxFee, hasTon {
            presentInsufficientFee(.insufficientTrxSoft(trxFee))
            return
        }

        if let trxFee, !hasTon {
            presentInsufficientFee(.insufficientTrxSoft(trxFee))
            return
        }

        if !hasTon, !hasTron {
            state = .failed(.generic)
            return
        }

        await applyReady(
            sendTon: hasTon,
            sendTron: hasTron,
            ton: tonResult,
            tron: tronResult,
            preparationID: preparationID
        )
    }

    func continueWithAvailableChain() {
        guard case let .failed(failure) = state else { return }

        Task {
            guard let preparationID else { return }
            switch failure {
            case .insufficientTonSoft:
                guard let tron = pendingTronResult else { return }
                state = .loading
                await applyReady(
                    sendTon: false,
                    sendTron: true,
                    ton: nil,
                    tron: tron,
                    preparationID: preparationID
                )
            case .insufficientTrxSoft:
                guard let ton = pendingTonResult else { return }
                state = .loading
                await applyReady(
                    sendTon: true,
                    sendTron: false,
                    ton: ton,
                    tron: nil,
                    preparationID: preparationID
                )
            case .generic, .insufficientFees:
                break
            }
        }
    }

    func retry() async {
        await start()
    }

    func back() {
        onBack()
    }

    func close() {
        onClose()
    }

    func showMigrationInfo() {
        onShowMigrationInfo()
    }

    func openTonFeeMethodPicker() {
        guard sendTon,
              let ton = preparedResult,
              let selectedTonFeeMethod
        else {
            return
        }

        openFeeMethodPicker(
            methods: ton.availableFeeMethods,
            selectedMethod: selectedTonFeeMethod,
            leading: { $0.networkFeePickerLeading },
            title: { $0.networkFeePickerTitle },
            subtitle: { [weak self] in self?.tonFeeValueText(for: $0) ?? "" },
            isInsufficient: { [weak self] in self?.isTonFeeMethodInsufficient($0) == true },
            onInsufficient: { [weak self] method in
                if case .battery = method {
                    self?.requestBatteryRefill()
                } else {
                    self?.requestTonDeposit()
                }
            },
            onSelect: { [weak self] in self?.selectTonFeeMethod($0) }
        )
    }

    func openTronFeeMethodPicker() {
        guard sendTron,
              let tron = preparedTronResult,
              let selectedTronFeeMethod
        else {
            return
        }

        openFeeMethodPicker(
            methods: tron.availableFeeMethods,
            selectedMethod: selectedTronFeeMethod,
            leading: { $0.networkFeePickerLeading },
            title: { $0.networkFeePickerTitle },
            subtitle: { [weak self] in self?.tronFeeValueText(for: $0) ?? "" },
            isInsufficient: { [weak self] in self?.isTronFeeMethodInsufficient($0) == true },
            onInsufficient: { [weak self] method in
                guard let self else { return }
                switch tronFeeShortage(method) {
                case .trx:
                    requestTrxDeposit()
                case .battery:
                    requestBatteryRefill()
                case nil:
                    break
                }
            },
            onSelect: { [weak self] in self?.selectTronFeeMethod($0) }
        )
    }

    private func openFeeMethodPicker<Method: Equatable>(
        methods: [Method],
        selectedMethod: Method,
        leading: (Method) -> NetworkFeePickerItem.Leading,
        title: (Method) -> String,
        subtitle: (Method) -> String,
        isInsufficient: @escaping (Method) -> Bool,
        onInsufficient: @escaping (Method) -> Void,
        onSelect: @escaping (Method) -> Void
    ) {
        guard methods.count > 1 || isInsufficient(selectedMethod) else { return }

        let items = methods.enumerated().map { index, method in
            let isInsufficient = isInsufficient(method)
            return NetworkFeePickerItem(
                id: "\(index)",
                leading: leading(method),
                text: .titled(title: title(method), subtitle: subtitle(method)),
                isDisabled: isInsufficient,
                actionTitle: isInsufficient ? TKLocales.FeeMethodPicker.deposit : nil,
                isSelected: method == selectedMethod
            )
        }

        onOpenFeePicker(
            NetworkFeePickerPresentation(
                configuration: NetworkFeePickerConfiguration(
                    title: TKLocales.FeeMethodPicker.title,
                    subtitle: TKLocales.FeeMethodPicker.subtitle
                ),
                dataSource: StaticNetworkFeePickerDataSource(items: items),
                didSelectItem: { item, _ in
                    guard let index = Int(item.id), methods.indices.contains(index) else { return }
                    let method = methods[index]
                    if isInsufficient(method) {
                        onInsufficient(method)
                    } else {
                        onSelect(method)
                    }
                }
            )
        )
    }

    func confirmSwipe() {
        guard canStartConfirm else { return }
        startConfirm()
    }

    func tryAgain() {
        guard confirmationState == .retry else { return }
        startConfirm()
    }

    private func startConfirm() {
        guard canStartConfirm else { return }

        confirmationState = .confirming

        let payload = ConfirmPayload(
            ton: sendTon ? preparedResult : nil,
            tron: sendTron ? preparedTronResult : nil,
            sendTon: sendTon,
            sendTron: sendTron,
            tonFeeMethod: sendTon ? selectedTonFeeMethod : nil,
            tronFeeMethod: sendTron ? selectedTronFeeMethod : nil
        )

        let feeAsset = currentFeeAsset

        confirmTask = Task {
            do {
                try await onConfirm(payload)
                analyticsProvider.log(MigrateTransactionSuccess(feeAsset: feeAsset))
                confirmationState = .success
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                onSuccess()
            } catch is CancellationError {
                if confirmationState == .confirming {
                    confirmationState = .idle
                }
            } catch {
                guard !Task.isCancelled else { return }
                logConfirmationFailure(error, feeAsset: feeAsset)
                presentSendFailureReason(error)
                let isPartial = (error as? WalletMigrationPartFailure)?.isPartial == true
                confirmationState = .failed
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                guard confirmationState == .failed else { return }
                if isPartial {
                    confirmationState = .idle
                    state = .failed(.generic)
                } else {
                    confirmationState = .retry
                }
            }
        }
    }

    private func presentSendFailureReason(_ error: Error) {
        guard let message = WalletMigrationSendFailureMessage.extract(from: error) else { return }
        ToastPresenter.showToast(configuration: .defaultConfiguration(text: message))
    }

    private func logConfirmationFailure(_ error: Error, feeAsset: FeeAsset) {
        let partFailure = error as? WalletMigrationPartFailure
        let mapped = analyticsError(
            from: partFailure?.underlying ?? error,
            fallbackType: .transactionSendFailed
        )
        analyticsProvider.log(
            MigrateTransactionError(
                feeAsset: feeAsset,
                failedPart: partFailure?.part ?? .setup,
                isPartial: partFailure?.isPartial ?? false,
                errorType: mapped.type.rawValue,
                errorCode: mapped.code,
                errorMessage: mapped.message
            )
        )
    }

    private func logPrepareFailure(_ error: Error?, chain: AssetChain) {
        guard let error else { return }
        let mapped = analyticsError(from: error, fallbackType: .feeCalculationFailed)
        analyticsProvider.log(
            MigrateTransactionPrepareError(
                chain: chain,
                isBlocking: !(state == .ready || showsContinueOnFailure),
                errorType: mapped.type.rawValue,
                errorCode: mapped.code,
                errorMessage: mapped.message
            )
        )
    }

    private func analyticsError(from error: Error, fallbackType: RedAnalyticsErrorType) -> AnalyticsError {
        (error as? AnalyticsError) ?? AnyAnalyticsError(
            type: fallbackType,
            message: error.localizedDescription,
            code: 0
        )
    }

    private var currentFeeAsset: FeeAsset {
        FeeAsset(
            tonFeeMethod: sendTon ? selectedTonFeeMethod : nil,
            tronFeeMethod: sendTron ? selectedTronFeeMethod : nil
        )
    }

    private func applyReady(
        sendTon: Bool,
        sendTron: Bool,
        ton: WalletMigrationPrepareResult?,
        tron: WalletMigrationTronPrepareResult?,
        preparationID: UUID
    ) async {
        guard isCurrentPreparation(preparationID) else { return }

        self.sendTon = sendTon
        self.sendTron = sendTron
        preparedResult = ton
        preparedTronResult = tron
        let selection = WalletMigrationFeeSelectionResolver.preferred(
            ton: sendTon ? ton : nil,
            tron: sendTron ? tron : nil,
            availableBatteryCharges: availableBatteryCharges
        )
        selectedTonFeeMethod = selection.ton
        selectedTronFeeMethod = selection.tron

        await loadRatesIfNeeded(sendTon: sendTon, sendTron: sendTron)
        guard isCurrentPreparation(preparationID) else { return }
        updateFeeRowModels()

        if sendTon, let ton {
            loadedNFTs = await loadNFTs(from: ton)
        } else {
            loadedNFTs = [:]
        }

        guard isCurrentPreparation(preparationID) else { return }

        remappedItems()

        if state == .ready, !hasLoggedConfirmationView {
            hasLoggedConfirmationView = true
            analyticsProvider.log(MigrateTransactionConfirmationView(feeAsset: currentFeeAsset))
        }
    }

    private func selectTonFeeMethod(_ method: WalletMigrationPrepareResult.FeeMethod) {
        guard !isTonFeeMethodInsufficient(method) else { return }
        selectedTonFeeMethod = method
        updateFeeRowModels()
        remappedItems()
    }

    private func selectTronFeeMethod(_ method: WalletMigrationTronPrepareResult.FeeMethod) {
        guard !isTronFeeMethodInsufficient(method) else { return }
        selectedTronFeeMethod = method
        updateFeeRowModels()
        remappedItems()
    }

    private func remappedItems() {
        let mapped = WalletMigrationConfirmationMapper.map(
            prepareResult: sendTon ? preparedResult : nil,
            tonFeeMethod: sendTon ? selectedTonFeeMethod : nil,
            tronPrepareResult: sendTron ? preparedTronResult : nil,
            tronFeeMethod: sendTron ? selectedTronFeeMethod : nil,
            usdtRate: usdtRate,
            trxRate: trxRate,
            amountFormatter: amountFormatter,
            currency: currencyStore.state,
            isSecureMode: appSettingsStore.state.isSecureMode,
            nftProvider: { [walletNFTsRepository, sourceWallet, nftService, loadedNFTs] address in
                if let nft = loadedNFTs[address] {
                    return nft
                }
                if let nft = walletNFTsRepository.get(wallet: sourceWallet).all.first(where: { $0.address == address }) {
                    return nft
                }
                return try? nftService.getNFT(address: address, network: sourceWallet.network)
            }
        )

        items = mapped.items
        totalSummary = mapped.totalSummary

        if mapped.items.isEmpty {
            state = .failed(.generic)
        } else {
            state = .ready
        }
    }

    private func updateFeeRowModels() {
        tonFeeRowModel = makeTonFeeRowModel()
        tronFeeRowModel = makeTronFeeRowModel()
    }

    private func makeTonFeeRowModel() -> FeeRowModel? {
        guard sendTon,
              let ton = preparedResult,
              let selectedTonFeeMethod
        else {
            return nil
        }

        return FeeRowModel(
            title: TKLocales.Settings.Migration.tonFee,
            value: tonFeeValueText(for: selectedTonFeeMethod),
            method: selectedTonFeeMethod.feeRowMethodTitle,
            canPickMethod: ton.availableFeeMethods.count > 1
                || isTonFeeMethodInsufficient(selectedTonFeeMethod)
        )
    }

    private func makeTronFeeRowModel() -> FeeRowModel? {
        guard sendTron,
              let selectedTronFeeMethod,
              let tron = preparedTronResult
        else {
            return nil
        }

        return FeeRowModel(
            title: TKLocales.Settings.Migration.tronFee,
            value: tronFeeValueText(for: selectedTronFeeMethod),
            method: selectedTronFeeMethod.feeRowMethodTitle,
            canPickMethod: tron.availableFeeMethods.count > 1
                || isTronFeeMethodInsufficient(selectedTronFeeMethod)
        )
    }

    private func offersBatteryFeeMethod(_ ton: WalletMigrationPrepareResult?) -> Bool {
        ton?.availableFeeMethods.contains(where: \.isBattery) == true
    }

    private func tonShortage(
        ton: WalletMigrationPrepareResult,
        availableBatteryCharges: Int?
    ) -> InsufficientFeeAmounts? {
        let shortage = ton.blockingTONShortage { method in
            WalletMigrationFeeSelectionResolver.isTonMethodPayable(
                method,
                ton: ton,
                availableBatteryCharges: availableBatteryCharges
            )
        }
        return shortage.map {
            InsufficientFeeAmounts(required: $0.required, available: $0.available)
        }
    }

    /// Battery only counts as a way out when at least one complete TON + TRON fee selection can pay.
    private func trxShortage(
        tron: WalletMigrationTronPrepareResult,
        ton: WalletMigrationPrepareResult?,
        availableBatteryCharges: Int?
    ) -> InsufficientFeeAmounts? {
        let shortage = tron.blockingTRXShortage { method in
            WalletMigrationFeeSelectionResolver.isTronMethodPayable(
                method,
                ton: ton,
                tron: tron,
                availableBatteryCharges: availableBatteryCharges
            )
        }
        return shortage.map {
            InsufficientFeeAmounts(
                required: UInt64(clamping: $0.required),
                available: UInt64(clamping: $0.available)
            )
        }
    }

    private var isSelectedFeeInsufficient: Bool {
        WalletMigrationFeeSelectionResolver.isInsufficient(
            selection: WalletMigrationFeeSelection(
                ton: sendTon ? selectedTonFeeMethod : nil,
                tron: sendTron ? selectedTronFeeMethod : nil
            ),
            ton: sendTon ? preparedResult : nil,
            tron: sendTron ? preparedTronResult : nil,
            availableBatteryCharges: availableBatteryCharges
        )
    }

    private func isTonFeeMethodInsufficient(
        _ method: WalletMigrationPrepareResult.FeeMethod?
    ) -> Bool {
        WalletMigrationFeeSelectionResolver.isTonMethodInsufficient(
            method,
            ton: preparedResult,
            tronMethod: sendTron ? selectedTronFeeMethod : nil,
            availableBatteryCharges: availableBatteryCharges
        )
    }

    private func isTronFeeMethodInsufficient(
        _ method: WalletMigrationTronPrepareResult.FeeMethod?
    ) -> Bool {
        tronFeeShortage(method) != nil
    }

    private func tronFeeShortage(
        _ method: WalletMigrationTronPrepareResult.FeeMethod?
    ) -> WalletMigrationTronFeeShortage? {
        WalletMigrationFeeSelectionResolver.tronShortage(
            method,
            tron: preparedTronResult,
            tonMethod: sendTon ? selectedTonFeeMethod : nil,
            availableBatteryCharges: availableBatteryCharges
        )
    }

    private func requestTonDeposit() {
        onDepositTon { [weak self] in self?.reloadAfterDeposit() }
    }

    private func requestTrxDeposit() {
        onDepositTrx { [weak self] in self?.reloadAfterDeposit() }
    }

    private func requestWalletDeposit() {
        onDepositWallet { [weak self] in self?.reloadAfterDeposit() }
    }

    private func reloadAfterDeposit() {
        Task { await start() }
    }

    private func requestBatteryRefill() {
        onRefillBattery { [weak self] in
            Task { await self?.start() }
        }
    }

    private func isCurrentPreparation(_ id: UUID) -> Bool {
        preparationID == id && !Task.isCancelled
    }

    private func tonFeeValueText(for method: WalletMigrationPrepareResult.FeeMethod) -> String {
        if appSettingsStore.state.isSecureMode {
            return String.secureModeValueShort
        }

        switch method {
        case let .battery(charges):
            return "\(charges) \(TKLocales.Battery.Refill.chargesCount(count: charges))"
        case let .ton(amountNano):
            return feeValueText(
                amount: BigUInt(amountNano),
                fractionDigits: TonToken.ton.fractionDigits,
                rate: tonRate
            )
        }
    }

    private func tronFeeValueText(for method: WalletMigrationTronPrepareResult.FeeMethod) -> String {
        if appSettingsStore.state.isSecureMode {
            return String.secureModeValueShort
        }

        switch method {
        case let .battery(charges):
            return "\(charges) \(TKLocales.Battery.Refill.chargesCount(count: charges))"
        case let .trx(amountSun):
            return feeValueText(
                amount: amountSun,
                fractionDigits: TRX.fractionDigits,
                rate: trxRate
            )
        }
    }

    private func feeValueText(
        amount: BigUInt,
        fractionDigits: Int,
        rate: Rates.Rate?
    ) -> String {
        if appSettingsStore.state.isSecureMode {
            return String.secureModeValueShort
        }

        if let rate,
           let fiat = formatFiat(amount: amount, fractionDigits: fractionDigits, rate: rate)
        {
            return "\(TKLocales.Common.Numbers.approximate) \(fiat)"
        }

        let token = amountFormatter.format(
            amount: amount,
            fractionDigits: fractionDigits,
            isNegative: false,
            style: .compact
        )
        return "\(TKLocales.Common.Numbers.approximate) \(token)"
    }

    private func formatFiat(
        amount: BigUInt,
        fractionDigits: Int,
        rate: Rates.Rate
    ) -> String? {
        let converted = RateConverter().convert(
            amount: amount,
            amountFractionLength: fractionDigits,
            rate: rate
        )
        return amountFormatter.format(
            amount: converted.amount,
            fractionDigits: converted.fractionLength,
            accessory: .fiat(currencyStore.state),
            isNegative: false,
            style: .compact
        )
    }

    private func loadRatesIfNeeded(sendTon: Bool, sendTron: Bool) async {
        let currency = currencyStore.state
        let cached = tonRatesStore.getState()
        tonRate = cached.tonRates.first(where: { $0.currency == currency })
        usdtRate = cached.usdtRates.first(where: { $0.currency == currency })

        var jettons: [String] = []
        if sendTron {
            jettons.append(TRX.symbol.uppercased())
        }

        guard !jettons.isEmpty || tonRate == nil else { return }

        do {
            let rates = try await ratesService.loadRates(
                jettons: jettons,
                currencies: [currency]
            )
            if tonRate == nil {
                tonRate = rates.ton.first(where: { $0.currency == currency })
            }
            if usdtRate == nil {
                usdtRate = rates.usdt.first(where: { $0.currency == currency })
            }
            trxRate = rates.jettonRates.first {
                $0.key.uppercased() == TRX.symbol.uppercased()
            }?
                .value
                .first(where: { $0.currency == currency })
        } catch {
            return
        }
    }

    private func presentInsufficientFee(_ failure: Failure) {
        state = .failed(failure)
        guard let content = insufficientFeePopupContent(for: failure) else { return }
        onPresentInsufficientFee(content)
    }

    private func insufficientFeePopupContent(
        for failure: Failure
    ) -> InsufficientFeePopupContent? {
        let walletTitle = InsufficientFeePopupContent.walletTitle(for: sourceWallet)
        switch failure {
        case .generic:
            return nil
        case let .insufficientTonSoft(ton):
            let (required, available) = formatTonAmounts(ton)
            return InsufficientFeePopupContent(
                title: TKLocales.Settings.Migration.Error.InsufficientTon.title(walletTitle.argument),
                caption: TKLocales.Settings.Migration.Error.InsufficientTon.details(
                    required,
                    available
                ),
                description: showsContinueOnFailure
                    ? TKLocales.Settings.Migration.Error.InsufficientTon.description
                    : nil,
                // Continuing with the other chain is the expected action here, so it takes the primary button.
                primaryButtonTitle: showsContinueOnFailure
                    ? TKLocales.Settings.Migration.Error.continue
                    : TKLocales.Settings.Migration.Error.InsufficientTon.deposit,
                secondaryButtonTitle: showsContinueOnFailure
                    ? TKLocales.Settings.Migration.Error.InsufficientTon.deposit
                    : nil,
                primaryAction: showsContinueOnFailure ? .continueMigration : .deposit,
                walletIcon: walletTitle.icon,
                walletName: walletTitle.name,
                walletNamePlaceholder: walletTitle.namePlaceholder
            )
        case let .insufficientTrxSoft(trx):
            let (required, available) = formatTrxAmounts(trx)
            return InsufficientFeePopupContent(
                title: TKLocales.Settings.Migration.Error.InsufficientTrx.title(walletTitle.argument),
                caption: TKLocales.Settings.Migration.Error.InsufficientTrx.details(
                    required,
                    available
                ),
                description: showsContinueOnFailure
                    ? TKLocales.Settings.Migration.Error.InsufficientTrx.description
                    : nil,
                primaryButtonTitle: showsContinueOnFailure
                    ? TKLocales.Settings.Migration.Error.continue
                    : TKLocales.Settings.Migration.Error.InsufficientTrx.deposit,
                secondaryButtonTitle: showsContinueOnFailure
                    ? TKLocales.Settings.Migration.Error.InsufficientTrx.deposit
                    : nil,
                primaryAction: showsContinueOnFailure ? .continueMigration : .deposit,
                walletIcon: walletTitle.icon,
                walletName: walletTitle.name,
                walletNamePlaceholder: walletTitle.namePlaceholder
            )
        case let .insufficientFees(ton, trx):
            let (tonRequired, tonAvailable) = formatTonAmounts(ton)
            let (trxRequired, trxAvailable) = formatTrxAmounts(trx)
            return InsufficientFeePopupContent(
                title: TKLocales.Settings.Migration.Error.InsufficientFees.title(walletTitle.argument),
                caption: TKLocales.Settings.Migration.Error.InsufficientFees.details(
                    tonRequired,
                    trxRequired,
                    tonAvailable,
                    trxAvailable
                ),
                primaryButtonTitle: TKLocales.Settings.Migration.Error.InsufficientFees.deposit,
                walletIcon: walletTitle.icon,
                walletName: walletTitle.name,
                walletNamePlaceholder: walletTitle.namePlaceholder
            )
        }
    }

    private func formatTonAmounts(_ amounts: InsufficientFeeAmounts) -> (String, String) {
        amountFormatter.formatDistinctly(
            BigUInt(amounts.required),
            BigUInt(amounts.available),
            fractionDigits: TonToken.ton.fractionDigits,
            accessory: .tokenSymbol(TonToken.ton.symbol)
        )
    }

    private func formatTrxAmounts(_ amounts: InsufficientFeeAmounts) -> (String, String) {
        amountFormatter.formatDistinctly(
            BigUInt(amounts.required),
            BigUInt(amounts.available),
            fractionDigits: TRX.fractionDigits,
            accessory: .tokenSymbol(TRX.symbol)
        )
    }

    private func loadNFTs(from result: WalletMigrationPrepareResult) async -> [TonSwift.Address: NFT] {
        var addresses = Set<TonSwift.Address>()

        for transaction in result.transactions {
            for action in transaction.event.actions {
                if case let .nftItemTransfer(transfer) = action.type {
                    addresses.insert(transfer.nftAddress)
                }
            }
        }

        guard !addresses.isEmpty else { return [:] }

        return (try? await nftService.loadNFTs(
            addresses: Array(addresses),
            network: sourceWallet.network
        )) ?? [:]
    }
}
