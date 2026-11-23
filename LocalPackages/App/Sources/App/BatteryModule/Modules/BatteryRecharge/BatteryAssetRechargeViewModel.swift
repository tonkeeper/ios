import AppUI
import BigInt
import Foundation
import KeeperCore
import SwiftUI
import TKLocalize
import TKLogging
import TKUIKit

@MainActor
final class BatteryAssetRechargeViewModel: ObservableObject {
    @Published private(set) var state: BatteryAssetRechargeViewState
    @Published private(set) var formState: BatteryRechargeFormState
    let amountInputViewModel: AmountInputSwiftUIViewModel
    var onSelectAsset: (() -> Void)?
    var willContinue: (() -> Void)?
    var endEditing: (() -> Void)?
    private(set) var selectedOptionID: String
    var isLoadingPaymentMethods = false {
        didSet { render() }
    }

    var canRetryEstimate: Bool {
        estimateFailed && !isBusy && !isTerminal
    }

    var amountField: BatteryAmountInputView.Field {
        .init(
            placeholder: TKLocales.Battery.Refill.amountPlaceholder(source.method.symbol),
            charges: amount > 0 ? state.charges : nil,
            available: TKLocales.Battery.Refill.amountAvailable(isSecureMode() ? String.secureModeValueShort : format(source.asset.balance))
        )
    }

    private let source: BatteryRechargeAsset
    private let wallet: Wallet
    private let purchaser: BatteryPurchasing
    private let loadBatteryBalance: () async throws -> NSDecimalNumber
    private let currency: () -> Currency
    private let isSecureMode: () -> Bool
    private let refresh: () async -> Void
    private let debounce: () async throws -> Void
    private var promo: String?
    private var pendingPromo: String?
    private let passcodeProvider: () async -> String?
    private let onSelect: (BatteryAnalyticsPurchase) -> Void
    private let onCredit: (BatteryAnalyticsPurchase) -> Void
    private let onSuccess: (BatteryAnalyticsPurchase) -> Void
    private let onClose: () -> Void
    private let formatter = AmountFormatter()
    private var text = ""
    private var amount: BigUInt = 0
    private var quote: BatteryPurchaseQuote?
    private var estimateFailed = false
    private var review: BatteryPurchaseReview?
    private var requestsConfirmation: Bool
    private lazy var estimates = BatteryPurchaseEstimates(
        estimate: { [purchaser, wallet] request in try await purchaser.estimate(wallet: wallet, request: request) },
        debounce: debounce,
        didChange: { [weak self] state in
            guard let self else { return }
            self.estimateFailed = false
            switch state {
            case .idle, .loading:
                self.quote = nil
                self.amountInputViewModel.setQuotedDestinationAmount(nil)
            case let .ready(quote):
                self.quote = quote
                self.amountInputViewModel.setQuotedDestinationAmount(BigUInt(max(0, quote.charges)))
                self.message = quote.charges == 0 ? TKLocales.Battery.Purchase.noCharges : nil
            case let .failed(error):
                self.estimateFailed = true
                Log.w("battery purchase estimate failed", error: error)
                self.message = Self.failureMessage(error)
            }
            self.render()
        }
    )
    private var actionTask: Task<Void, Never>?
    private var creditTask: Task<Void, Never>?
    private var resetToken = 0
    private var isBusy = false
    private var isTerminal = false
    private var isWaitingForCredit = false
    private var isActive = true
    private var hasLoggedSelect = false
    private var creditedPurchase: BatteryAnalyticsPurchase?
    private var message: String?

    init(source: BatteryRechargeAsset, amount: BigUInt?, promo: String?, wallet: Wallet, purchaser: BatteryPurchasing, loadBatteryBalance: @escaping () async throws -> NSDecimalNumber, currency: @escaping () -> Currency, isSecureMode: @escaping () -> Bool, refresh: @escaping () async -> Void, initialOptionID: String? = nil, passcodeProvider: @escaping () async -> String?, onSelect: @escaping (BatteryAnalyticsPurchase) -> Void, onCredit: @escaping (BatteryAnalyticsPurchase) -> Void, onSuccess: @escaping (BatteryAnalyticsPurchase) -> Void, onClose: @escaping () -> Void, debounce: @escaping () async throws -> Void = { try await Task.sleep(nanoseconds: 300_000_000) }) {
        self.source = source
        self.wallet = wallet
        self.purchaser = purchaser
        self.loadBatteryBalance = loadBatteryBalance
        self.currency = currency
        self.isSecureMode = isSecureMode
        self.refresh = refresh
        requestsConfirmation = amount != nil
        self.promo = promo
        pendingPromo = promo
        self.debounce = debounce
        self.passcodeProvider = passcodeProvider
        self.onSelect = onSelect
        self.onCredit = onCredit
        self.onSuccess = onSuccess
        self.onClose = onClose
        let amountOptionID = amount.map { amount in source.packages.first(where: { source.amount(for: $0) == amount })?.id ?? "custom" }
        let enabledPackIDs = source.packages.sorted { $0.charges > $1.charges }
            .filter { source.amount(for: $0).map(source.canBuy) == true }
            .map(\.id)
        let proposedOptionID = initialOptionID ?? amountOptionID ?? BatteryRefillViewModelImplementation.packId(previous: nil, enabledIds: enabledPackIDs) ?? "custom"
        let initialPack = source.packages.first { pack in
            pack.id == proposedOptionID && source.amount(for: pack).map(source.canBuy) == true
        }
        selectedOptionID = initialPack?.id ?? "custom"
        amountInputViewModel = AmountInputSwiftUIViewModel(amountFormatter: AmountFormatter(), sourceUnit: source.asset, destinationUnit: ChargeItem())
        formState = .init(title: TKLocales.Battery.Recharge.title, symbol: source.method.symbol, image: AssetIdResolver.imageSource(for: source.method.assetId, imageUrl: source.method.imageURL, multichainEnabled: true))
        state = .init(
            title: TKLocales.Battery.Recharge.title,
            network: source.method.chain?.displayTitle ?? "",
            image: AssetIdResolver.imageSource(for: source.method.assetId, imageUrl: source.method.imageURL, multichainEnabled: true),
            input: .init(text: "", symbol: .text(source.method.symbol), converted: nil, balance: nil)
        )
        let initialAmount = amount ?? initialPack.flatMap(source.amount(for:))
        if let amount = initialAmount, let value = BatteryRechargeMath.value(amount, decimals: source.method.decimals) {
            text = NSDecimalNumber(decimal: value).stringValue
            self.amount = amount
        }
        amountInputViewModel.sourceBalance = source.asset.balance
        amountInputViewModel.rate = NSDecimalNumber(decimal: source.rate ?? 0)
        amountInputViewModel.minimumSourceAmount = source.minimum
        amountInputViewModel.minimumDisplayStyle = .exactValue
        amountInputViewModel.setInitialSourceAmount(amount: self.amount)
        amountInputViewModel.didUpdateSourceAmount = { [weak self] in self?.updateAmount($0) }
        render()
    }

    func start() {
        isActive = true
        showSuccessIfActive()
        guard actionTask == nil, !isTerminal else { return }
        if requestsConfirmation, review == nil {
            proceed()
        } else {
            updateAmount(amount)
        }
    }

    func stop() {
        isActive = false
        estimates.cancel()
        actionTask?.cancel()
    }

    func suspendNavigation() {
        isActive = false
    }

    func close() {
        stop()
        onClose()
    }

    private func updateAmount(_ value: BigUInt) {
        guard !isBusy, !isTerminal, review == nil else { return }
        amount = value
        text = BatteryRechargeMath.value(value, decimals: source.method.decimals).map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        estimates.cancel()
        quote = nil
        message = nil
        render()
        estimates.update(source.canBuy(amount) ? request() : nil)
    }

    func selectPack(_ id: String) {
        guard !isBusy, !isTerminal, review == nil, id != selectedOptionID else { return }
        if id == "custom" {
            selectedOptionID = id
            amountInputViewModel.reset()
        } else if let pack = source.packages.first(where: { $0.id == id }), let amount = source.amount(for: pack), source.canBuy(amount) {
            selectedOptionID = id
            amountInputViewModel.setInitialSourceAmount(amount: amount)
        }
        render()
    }

    func updatePromo(_ state: BatteryPromocodeResolveState) {
        let value: String? = if case let .success(code) = state { code } else { nil }
        pendingPromo = value
        guard !isBusy, !isTerminal, promo != value else { return }
        review = nil
        quote = nil
        promo = value
        if requestsConfirmation {
            proceed()
        } else {
            updateAmount(amount)
        }
    }

    func editAmount() {
        guard !isBusy, !isTerminal else { return }
        requestsConfirmation = false
        review = nil
        promo = pendingPromo
        updateAmount(amount)
    }

    func retry() {
        guard !isBusy, !isTerminal else { return }
        if requestsConfirmation, review == nil {
            proceed()
        } else {
            updateAmount(amount)
        }
    }

    func proceed() {
        guard !isBusy, !isTerminal, source.canBuy(amount), (requestsConfirmation && review == nil) || (quote?.charges ?? 0) > 0 else { return }
        willContinue?()
        estimates.cancel()
        isBusy = true
        message = nil
        render()
        actionTask = Task { [weak self] in
            guard let self else { return }
            var balanceBeforeSend: NSDecimalNumber?
            defer {
                self.actionTask = nil
                self.isBusy = false
                self.resetToken += 1
                if self.isActive, !Task.isCancelled, self.review == nil, !self.isTerminal, self.promo != self.pendingPromo {
                    self.promo = self.pendingPromo
                    if self.requestsConfirmation {
                        self.proceed()
                    } else {
                        self.updateAmount(self.amount)
                    }
                } else {
                    self.render()
                }
            }
            do {
                if let review = self.review {
                    let before = try await self.loadBatteryBalance()
                    balanceBeforeSend = before
                    _ = try await self.purchaser.send(wallet: self.wallet, review: review, passcodeProvider: self.passcodeProvider)
                    self.isTerminal = true
                    self.isWaitingForCredit = true
                    self.message = TKLocales.Battery.Purchase.pending
                    self.render()
                    self.waitForCredit(after: before)
                } else {
                    if !self.hasLoggedSelect {
                        self.hasLoggedSelect = true
                        self.onSelect(self.analyticsPurchase)
                    }
                    if self.requestsConfirmation {
                        let quote = try await self.purchaser.estimate(wallet: self.wallet, request: self.request())
                        try Task.checkCancellation()
                        guard self.promo == self.pendingPromo else { return }
                        self.quote = quote
                        guard quote.charges > 0 else {
                            self.message = TKLocales.Battery.Purchase.noCharges
                            return
                        }
                    }
                    let review = try await self.purchaser.emulate(wallet: self.wallet, request: self.request())
                    try Task.checkCancellation()
                    guard self.promo == self.pendingPromo else { return }
                    self.review = review
                    self.quote = review.quote
                    if review.quote.charges == 0 { self.message = TKLocales.Battery.Purchase.noCharges }
                }
            } catch let BatteryPurchaseError.changedQuote(review) {
                self.review = review
                self.quote = review.quote
                self.message = review.quote.charges == 0 ? TKLocales.Battery.Purchase.noCharges : TKLocales.Battery.Purchase.quoteChanged
            } catch let BatteryPurchaseError.outcomeUnknown(sentReview) {
                self.isTerminal = true
                self.message = TKLocales.Battery.Purchase.outcomeUnknown
                self.isBusy = false
                self.isWaitingForCredit = balanceBeforeSend != nil
                self.render()
                if let balanceBeforeSend { self.waitForCredit(after: balanceBeforeSend, minimumCharges: sentReview.quote.charges, unknownOutcome: true) }
            } catch MultichainTransactionFailure.canceled {
            } catch {
                guard !Task.isCancelled else { return }
                Log.w("battery purchase failed", error: error)
                self.message = Self.failureMessage(error)
            }
        }
    }

    private var analyticsPurchase: BatteryAnalyticsPurchase {
        let size = source.packages.first(where: { source.amount(for: $0) == amount }).flatMap { BatteryAnalyticsPurchase.Size(rawValue: $0.id) } ?? .custom
        return .init(paymentType: .crypto(jetton: source.method.symbol), size: size, promocode: promo)
    }

    private static func failureMessage(_ error: Error) -> String {
        BatteryPurchaseError.isNetworkError(error)
            ? TKLocales.MultichainSwap.Screen.Confirm.Error.networkError
            : TKLocales.Multichain.Transaction.Error.failedToPrepare
    }

    private func request() -> BatteryPurchaseRequest {
        .init(method: source.method, sender: source.sender, amount: amount, promo: promo)
    }

    private func waitForCredit(after balance: NSDecimalNumber, minimumCharges: Int64 = 0, unknownOutcome: Bool = false) {
        let purchase = analyticsPurchase
        let minimumIncreaseTON: NSDecimalNumber? = unknownOutcome
            ? source.chargeCost.flatMap { BatteryRechargeMath.tonAmount(charges: minimumCharges, chargeCost: $0) }.map(NSDecimalNumber.init(decimal:))
            : .zero
        let monitor = BatteryPurchaseCreditMonitor(
            loadBalance: loadBatteryBalance,
            refresh: refresh
        )
        creditTask = monitor.start(after: balance, minimumIncreaseTON: minimumIncreaseTON) { [weak self, onCredit] result in
            defer { if result == .credited { onCredit(purchase) } }
            guard let self else { return }
            creditTask = nil
            isWaitingForCredit = false
            message = result == .credited ? TKLocales.Battery.Refill.Toast.recharged : (unknownOutcome ? TKLocales.Battery.Purchase.outcomeUnknown : TKLocales.Battery.Purchase.delayed)
            render()
            if result == .credited {
                creditedPurchase = purchase
                showSuccessIfActive()
            }
        }
    }

    private func showSuccessIfActive() {
        guard isActive, let purchase = creditedPurchase else { return }
        creditedPurchase = nil
        onSuccess(purchase)
    }

    private func format(_ amount: BigUInt) -> String {
        formatter.format(amount: amount, fractionDigits: source.method.decimals, accessory: .tokenSymbol(source.method.symbol), style: .exactValue)
    }

    private func render() {
        var warning = message
        if amount > source.asset.balance {
            warning = TKLocales.InsufficientFunds.insufficientBalance
        } else if amount > 0, let minimum = source.minimum, amount < minimum {
            warning = TKLocales.MultichainSwap.Screen.Swap.minimumAmount(format(minimum))
        }
        let value = BatteryRechargeMath.value(amount, decimals: source.method.decimals) ?? 0
        let localCharges = source.rate.map { BatteryRechargeMath.charges(amount: value, rate: $0) } ?? 0
        let pluralCount = quote.map { Int(clamping: $0.charges) } ?? Int(localCharges.description) ?? Int.max
        let count = quote.map { formatter.format(decimal: Decimal($0.charges), style: .compact) } ?? "≈ " + formatter.format(amount: localCharges, fractionDigits: 0, style: .compact)
        let currency = currency()
        let fiat = source.fiatAmount(amount, currency: currency).map { "≈ " + formatter.format(decimal: $0, accessory: .fiat(currency), style: .compact) } ?? ""
        let rows = source.packages.sorted { $0.charges > $1.charges }
        let packs = rows.enumerated().compactMap { index, pack -> BatteryRefillViewState.Pack? in
            guard let amount = source.amount(for: pack) else { return nil }
            let belowMinimum = amount < (source.minimum ?? 0)
            return .init(id: pack.id, title: formatter.format(amount: amount, fractionDigits: source.method.decimals, accessory: .tokenSymbol(source.method.symbol), style: .compact), caption: belowMinimum ? TKLocales.MultichainSwap.Screen.Swap.minimumAmount(format(source.minimum ?? 0)) : formatter.format(decimal: Decimal(pack.charges), style: .compact) + " " + TKLocales.Battery.Refill.chargesCount(count: pack.charges), icon: .fill(CGFloat(pack.charges) / CGFloat(max(rows.first?.charges ?? 1, 1))), tag: index == 0 && rows.count > 1 ? TKLocales.Battery.Refill.bestValue : nil, isEnabled: source.canBuy(amount), isSelected: selectedOptionID == pack.id)
        } + [.init(id: "custom", title: TKLocales.Battery.Recharge.СustomInput.title, caption: TKLocales.Battery.Recharge.СustomInput.caption, icon: .other, isSelected: selectedOptionID == "custom")]
        formState = .init(title: TKLocales.Battery.Recharge.title, symbol: source.method.symbol, image: AssetIdResolver.imageSource(for: source.method.assetId, imageUrl: source.method.imageURL, multichainEnabled: true), packs: packs, showsAmount: selectedOptionID == "custom", isEnabled: source.canBuy(amount) && (quote?.charges ?? 0) > 0, isBusy: isBusy, isLoadingPaymentMethods: isLoadingPaymentMethods, message: amount > 0 && !source.canBuy(amount) ? nil : warning, continueIdentifier: "battery_purchase_continue")
        state = .init(
            title: TKLocales.Battery.Refill.Crypto.recharge + " " + source.method.symbol,
            network: source.method.chain?.displayTitle ?? "",
            image: AssetIdResolver.imageSource(for: source.method.assetId, imageUrl: source.method.imageURL, multichainEnabled: true),
            input: .init(text: text, symbol: .text(source.method.symbol), converted: nil, balance: .init(text: TKLocales.Battery.Refill.balance(isSecureMode() ? String.secureModeValueShort : format(source.asset.balance > amount ? source.asset.balance - amount : 0)), isError: !source.canBuy(amount) && amount > 0, showsMax: false), textFieldAccessibilityIdentifier: "battery_purchase_amount"),
            charges: count + " " + TKLocales.Battery.Refill.chargesCount(count: pluralCount),
            fiat: fiat,
            fee: quote.map { formatter.format(decimal: Decimal($0.feeCharges), style: .compact) + " " + TKLocales.Battery.Refill.chargesCount(count: Int($0.feeCharges)) },
            message: warning,
            isConfirmation: requestsConfirmation || review != nil,
            canRetry: requestsConfirmation && review == nil && message != nil,
            isBusy: isBusy || isWaitingForCredit,
            isEnabled: source.canBuy(amount) && (quote?.charges ?? 0) > 0 && (!requestsConfirmation || review != nil),
            isTerminal: isTerminal,
            resetToken: resetToken
        )
    }
}

struct BatteryAssetRechargeContainer: View {
    @ObservedObject var model: BatteryAssetRechargeViewModel
    let promocodeViewModel: BatteryPromocodeInputViewModel
    let showsPromocode: Bool

    var body: some View {
        if model.state.isConfirmation || model.state.isTerminal {
            BatteryAssetRechargeView(state: model.state, onAmount: { _ in }, onContinue: model.proceed, onClose: model.close, onRetry: model.retry, onEdit: model.editAmount)
        } else {
            BatteryRechargeForm(state: model.formState, onSelectPack: model.selectPack, onSelectAsset: { model.onSelectAsset?() }, onContinue: model.proceed, onClose: model.close, endEditing: { model.endEditing?() }, onRetry: retryAction, amount: {
                BatteryAmountInputView(viewModel: model.amountInputViewModel, field: model.amountField, accessibilityIdentifier: "battery_purchase_amount")
            }, promo: {
                if showsPromocode {
                    BatteryPromocodeInputView(viewModel: promocodeViewModel)
                }
            }, recipient: { EmptyView() })
        }
    }

    private var retryAction: (() -> Void)? {
        guard model.canRetryEstimate else { return nil }
        return { model.retry() }
    }
}

@MainActor
final class BatteryAssetRechargeHostingViewController: TKHostingController<BatteryAssetRechargeContainer>, BatteryRechargePickerHosting {
    private let model: BatteryAssetRechargeViewModel

    var allowsAssetSelection: Bool {
        !model.state.isBusy && !model.state.isConfirmation && !model.state.isTerminal
    }

    init(model: BatteryAssetRechargeViewModel, promocodeViewModel: BatteryPromocodeInputViewModel, showsPromocode: Bool) {
        self.model = model
        super.init(content: BatteryAssetRechargeContainer(model: model, promocodeViewModel: promocodeViewModel, showsPromocode: showsPromocode))
        model.endEditing = { [weak self] in self?.view.endEditing(true) }
        promocodeViewModel.didUpdateResolvingState = { [weak model] in model?.updatePromo($0) }
    }

    @available(*, unavailable)
    dynamic required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true { model.suspendNavigation() }
    }

    func setPaymentMethodsLoading(_ loading: Bool) {
        model.isLoadingPaymentMethods = loading
    }

    func stopForAssetChange() {
        model.stop()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true { model.stop() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        model.start()
    }
}
