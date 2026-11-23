import BigInt
import Foundation
import KeeperCore
import TKLogging

final class BatteryRechargeModel {
    enum OptionItem: Equatable {
        struct Prefilled: Equatable {
            let identifier: String
            let chargesCount: Int
            let tokenAmount: BigUInt
            let tokenSymbol: String
            let tokenDigits: Int
            let fiatAmount: Decimal?
            let currency: Currency
            let batteryPercent: CGFloat
            let isEnable: Bool
        }

        case prefilled(Prefilled)
        case custom

        var identifier: String {
            switch self {
            case let .prefilled(prefilled):
                prefilled.identifier
            case .custom:
                "custom"
            }
        }

        var isEnable: Bool {
            switch self {
            case let .prefilled(prefilled):
                prefilled.isEnable
            case .custom:
                true
            }
        }
    }

    var didUpdateOptionItems: (() -> Void)?
    private(set) var optionsItems = [OptionItem]() {
        didSet { didUpdateOptionItems?() }
    }

    var didUpdateIsContinueEnable: (() -> Void)?
    private(set) var isContinueEnable = false {
        didSet { didUpdateIsContinueEnable?() }
    }

    var didUpdateIsCustomInputEnable: (() -> Void)?
    private(set) var isCustomInputEnable = false {
        didSet { didUpdateIsCustomInputEnable?() }
    }

    var didUpdateToken: (() -> Void)?
    var didUpdateRate: (() -> Void)?

    var selectedOptionItem: OptionItem? {
        didSet {
            switch selectedOptionItem {
            case let .prefilled(prefilled):
                isCustomInputEnable = false
                amount = prefilled.tokenAmount
            case .custom:
                isCustomInputEnable = true
                amount = 0
            case nil:
                isCustomInputEnable = false
                amount = 0
            }
        }
    }

    var didUpdateBalance: (() -> Void)?
    var balance: BigUInt {
        let balance = balanceStore.getState()[wallet]?.walletBalance.balance
        switch token {
        case .ton:
            return BigUInt(balance?.tonBalance.amount ?? 0)
        case let .jetton(jettonItem):
            return (balance?.jettonsBalance.first(where: { $0.item == jettonItem })?.quantity ?? 0)
        }
    }

    var amount: BigUInt = 0 {
        didSet {
            updateIsContinueEnable()
        }
    }

    var token: TonToken {
        didSet {
            start()
        }
    }

    /// The least amount the wallet can pay with this token now, if there is one.
    var minimumAmount: BigUInt? {
        guard case .jetton = token else { return nil }
        let walletBalance = balanceStore.getState()[wallet]?.walletBalance
        return Self.minimumAmount(
            batteryBalance: walletBalance?.batteryBalance,
            tonBalance: walletBalance?.balance.tonBalance.amount ?? 0,
            minBootstrapValue: rechargeMethod()?.minBootstrapValue,
            fractionDigits: token.fractionDigits
        )
    }

    var promocode: String?
    var isPromocodeEnabled: Bool {
        !configuration.isDisableBatteryPromoModule(network: wallet.network)
    }

    var recipient: TonRecipient? {
        didSet {
            updateIsContinueEnable()
        }
    }

    private(set) var tonChargeRate: NSDecimalNumber = 0 {
        didSet {
            didUpdateRate?()
        }
    }

    private(set) var chargeTonRate: NSDecimalNumber = 0

    private var chargeCost: String?
    private var hasChargeRate = false

    private var packages = [(name: String, charges: Int)]() {
        didSet { updateOptionsItems() }
    }

    private var jettonRate: Rates.Rate? {
        didSet { updateOptionsItems() }
    }

    private var jettonRateTask: Task<Void, Never>?

    private let wallet: Wallet
    private let balanceStore: BalanceStore
    private let currencyStore: CurrencyStore
    private let tonRatesStore: TonRatesStore
    private let ratesService: RatesService
    private let batteryService: BatteryService
    private let configuration: Configuration
    let isGift: Bool

    init(
        token: TonToken,
        wallet: Wallet,
        balanceStore: BalanceStore,
        currencyStore: CurrencyStore,
        tonRatesStore: TonRatesStore,
        ratesService: RatesService,
        batteryService: BatteryService,
        configuration: Configuration,
        isGift: Bool
    ) {
        self.token = token
        self.wallet = wallet
        self.balanceStore = balanceStore
        self.currencyStore = currencyStore
        self.tonRatesStore = tonRatesStore
        self.ratesService = ratesService
        self.batteryService = batteryService
        self.configuration = configuration
        self.isGift = isGift

        configuration.addUpdateObserver(self) { observer in
            DispatchQueue.main.async {
                observer.calculateTonChargeRate()
                observer.updateOptionsItems()
            }
        }
        balanceStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateBalanceState(wallet):
                guard wallet == observer.wallet else { return }
                DispatchQueue.main.async {
                    observer.updateOptionsItems()
                    observer.updateIsContinueEnable()
                    observer.didUpdateBalance?()
                }
            }
        }
        tonRatesStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateRates:
                guard wallet == observer.wallet else { return }
                DispatchQueue.main.async {
                    observer.updateOptionsItems()
                }
            }
        }
    }

    func getConfirmationPayload() -> BatteryRechargePayload {
        BatteryRechargePayload(
            token: token,
            amount: amount,
            promocode: promocode,
            recipient: recipient,
            analyticsPurchase: .crypto(option: selectedOptionItem, token: token, promocode: promocode)
        )
    }

    func start() {
        calculateTonChargeRate()
        loadJettonRate()
        updateOptionsItems()
        updateIsContinueEnable()
        didUpdateToken?()
        didUpdateRate?()
        if packages.isEmpty {
            loadPackages()
        }
    }

    private func loadPackages() {
        Task { @MainActor [weak self, batteryService, wallet] in
            do {
                let config = try await batteryService.loadBatteryConfig(wallet: wallet)
                self?.chargeCost = config.charge_cost
                self?.calculateTonChargeRate()
                self?.packages = config.packages
                    .filter { $0.name != .unknown && $0.charges > 0 }
                    .map { (name: $0.name.rawValue, charges: $0.charges) }
            } catch {
                Log.w("battery recharge: failed to load packages", error: error)
            }
        }
    }

    private func loadJettonRate() {
        jettonRateTask?.cancel()
        jettonRate = nil
        guard case let .jetton(jettonItem) = token else { return }
        let currency = currencyStore.getState()
        let address = jettonItem.jettonInfo.address.toRaw()
        jettonRateTask = Task { @MainActor [weak self, ratesService] in
            do {
                let rates = try await ratesService.loadRates(jettons: [address], currencies: [currency])
                guard !Task.isCancelled else { return }
                self?.jettonRate = rates.jettonRates[address]?.first(where: { $0.currency == currency })
            } catch {
                Log.w("battery recharge: failed to load jetton rate", error: error)
            }
        }
    }

    private func rechargeMethod() -> BatteryRechargeMethod? {
        let methods = batteryService.getRechargeMethods(wallet: wallet, includeRechargeOnly: false)
        switch token {
        case .ton:
            return methods.first(where: { $0.token == .ton })
        case let .jetton(jettonItem):
            return methods.first(where: { $0.jettonMasterAddress == jettonItem.jettonInfo.address })
        }
    }

    private func calculateTonChargeRate() {
        guard let method = rechargeMethod(),
              let rate = BatteryRechargeMath.chargesRate(
                  method.chargesRate,
                  rate: method.rate.stringValue,
                  chargeCost: chargeCost ?? configuration.batteryMeanFeesDecimaNumber(network: wallet.network)?.stringValue ?? "0"
              )
        else {
            hasChargeRate = false
            tonChargeRate = 0
            chargeTonRate = 0
            updateIsContinueEnable()
            return
        }
        hasChargeRate = true
        self.tonChargeRate = NSDecimalNumber(decimal: rate)
        self.chargeTonRate = NSDecimalNumber(decimal: 1 / rate)
        updateIsContinueEnable()
    }

    private func calculateTokenAmount(chargesCount: Int) -> BigUInt {
        guard hasChargeRate else { return 0 }
        return BatteryRechargeMath.amount(charges: chargesCount, rate: tonChargeRate.decimalValue, decimals: token.fractionDigits) ?? 0
    }

    private func calculateFiatAmount(tokenAmount: BigUInt, currency: Currency, rates: Rates.Rate?) -> Decimal? {
        guard let rates else { return nil }
        return RateConverter().convertToDecimal(amount: tokenAmount, amountFractionLength: token.fractionDigits, rate: rates)
    }

    private func updateIsContinueEnable() {
        let balance = balanceStore.getState()[wallet]?.walletBalance.balance
        let isAmountAvailable: Bool
        switch token {
        case .ton:
            isAmountAvailable = (balance?.tonBalance.amount ?? 0) >= amount
        case let .jetton(jettonItem):
            isAmountAvailable = (balance?.jettonsBalance.first(where: { $0.item == jettonItem })?.quantity ?? 0) >= amount
        }
        let chargesCount = Self.chargesCount(amount: amount, fractionDigits: token.fractionDigits, tonChargeRate: tonChargeRate)
        self.isContinueEnable = hasChargeRate
            && isAmountAvailable
            && amount > 0
            && amount >= (minimumAmount ?? 0)
            && chargesCount > 0
            && (!isGift || (isGift && recipient != nil))
    }

    static let selfPaidGasTonBalance: Int64 = 100_000_000

    /// Without charges, a jetton purchase goes through the relayer only from the method's
    /// `minBootstrapValue`; a smaller one is sent by the wallet itself and needs TON for its gas.
    static func minimumAmount(
        batteryBalance: BatteryBalance?,
        tonBalance: Int64,
        minBootstrapValue: NSDecimalNumber?,
        fractionDigits: Int
    ) -> BigUInt? {
        guard batteryBalance?.balanceDecimalNumber.compare(0) != .orderedDescending,
              tonBalance < selfPaidGasTonBalance,
              let minBootstrapValue,
              minBootstrapValue != .notANumber,
              minBootstrapValue.compare(0) == .orderedDescending
        else {
            return nil
        }
        let units = minBootstrapValue
            .multiplying(byPowerOf10: Int16(fractionDigits))
            .rounding(accordingToBehavior: NSDecimalNumberHandler.upRoundBehaviour)
        return BigUInt(units.stringValue)
    }

    static func chargesCount(amount: BigUInt, fractionDigits: Int, tonChargeRate: NSDecimalNumber) -> BigUInt {
        let chargeUnit = ChargeItem()
        return RateConverter().convert(
            amount: amount,
            amountFractionLength: fractionDigits,
            rate: tonChargeRate,
            targetFractionLength: chargeUnit.fractionalDigits,
            roundingMode: chargeUnit.conversionRounding.intoUnitMode
        )
    }

    private func updateOptionsItems() {
        let currency = currencyStore.getState()
        let balance = balanceStore.getState()[wallet]?.walletBalance.balance
        let rates: Rates.Rate? = {
            switch self.token {
            case .ton:
                return tonRatesStore.getState().tonRates.first(where: { $0.currency == currency })
            case let .jetton(jettonItem):
                return jettonRate ?? balance?
                    .jettonsBalance
                    .first(where: { $0.item == jettonItem })?
                    .rates[currency]
            }
        }()

        let maxCharges = packages.map { $0.charges }.max() ?? 0
        let minimumAmount = minimumAmount ?? 0
        var items = packages.map { package -> OptionItem in
            let tokenAmount = calculateTokenAmount(
                chargesCount: package.charges
            )

            let isEnable = tokenAmount > 0 && tokenAmount >= minimumAmount && {
                switch token {
                case .ton:
                    (balance?.tonBalance.amount ?? 0) >= tokenAmount
                case let .jetton(jettonItem):
                    (balance?.jettonsBalance.first(where: { $0.item == jettonItem })?.quantity ?? 0) >= tokenAmount
                }
            }()

            if package.name == selectedOptionItem?.identifier, !isEnable {
                self.selectedOptionItem = nil
            }

            let fiatAmount = calculateFiatAmount(tokenAmount: tokenAmount, currency: currency, rates: rates)

            return OptionItem.prefilled(
                OptionItem.Prefilled(
                    identifier: package.name,
                    chargesCount: package.charges,
                    tokenAmount: tokenAmount,
                    tokenSymbol: token.symbol,
                    tokenDigits: token.fractionDigits,
                    fiatAmount: fiatAmount,
                    currency: currency,
                    batteryPercent: CGFloat(package.charges) / CGFloat(maxCharges),
                    isEnable: isEnable
                )
            )
        }
        items.append(.custom)
        self.optionsItems = items
    }
}

private extension NSDecimalNumberHandler {
    static var upRoundBehaviour: NSDecimalNumberHandler {
        NSDecimalNumberHandler(
            roundingMode: .up,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
    }
}
