import BigInt
import Foundation
import TKLogging
import TonSwift
import TronSwift

public final class SendV3Controller {
    public enum Remaining {
        case insufficient
        case remaining(String)
    }

    private let wallet: Wallet
    private let balanceStore: ConvertedBalanceStore
    private let dnsService: DNSService
    private let tonRatesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let recipientResolver: RecipientResolver
    private let amountFormatter: AmountFormatter
    private let rateConverter: RateConverter
    private let multichainAssetBalanceProvider: MultichainAssetBalanceProvider

    init(
        wallet: Wallet,
        balanceStore: ConvertedBalanceStore,
        dnsService: DNSService,
        tonRatesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        recipientResolver: RecipientResolver,
        amountFormatter: AmountFormatter,
        multichainAssetBalanceProvider: MultichainAssetBalanceProvider,
        rateConverter: RateConverter = RateConverter()
    ) {
        self.wallet = wallet
        self.balanceStore = balanceStore
        self.dnsService = dnsService
        self.tonRatesStore = tonRatesStore
        self.currencyStore = currencyStore
        self.recipientResolver = recipientResolver
        self.amountFormatter = amountFormatter
        self.rateConverter = rateConverter
        self.multichainAssetBalanceProvider = multichainAssetBalanceProvider
    }

    public func resolveRecipient(input: String) async throws -> LegacyRecipient {
        try await recipientResolver.resolverRecipient(
            string: input,
            network: wallet.network
        )
    }

    public func convertInputStringToAmount(
        input: String,
        targetFractionalDigits: Int
    ) -> (amount: BigUInt, fraction: Int) {
        AmountInputFormatter.amount(
            from: input,
            targetFractionalDigits: targetFractionalDigits
        )
    }

    public func convertAmountToInputString(
        amount: BigUInt,
        fractionDigits: Int,
        symbol: String? = nil
    ) -> String {
        let formatted = amountFormatter.formatInput(
            amount: amount,
            fractionDigits: fractionDigits
        )

        if let symbol {
            return "\(formatted) \(symbol)"
        } else {
            return formatted
        }
    }

    public func isAmountAvailableToSend(amount: BigUInt, token: TonToken) -> Bool {
        guard let balance = balanceStore.state[wallet]?.balance else { return false }

        switch token {
        case .ton:
            return BigUInt(balance.tonBalance.tonBalance.amount) >= amount
        case let .jetton(jettonItem):
            let jettonBalance = balance.jettonsBalance.first(where: { $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo
            })?.jettonBalance
            let jettonBalanceAmount = jettonBalance?.scaledBalance ?? jettonBalance?.quantity ?? 0
            return jettonBalanceAmount >= amount
        }
    }

    public func isTronAmountAvailableToSend(token: TronToken, amount: BigUInt) -> Bool {
        guard let balance = tronBalance(token: token) else { return false }
        return balance >= amount
    }

    public func convertTokenAmountToCurrency(
        token: TonToken,
        _ amount: BigUInt,
        _ showCurrency: Bool = true
    ) -> String {
        let currency = currencyStore.state
        switch token {
        case .ton:
            guard let rate = tonRatesStore.state.tonRates.first(where: { $0.currency == currency }) else { return "" }

            let converted = rateConverter.convert(amount: amount, amountFractionLength: TonInfo.fractionDigits, rate: rate)
            let formatted = amountFormatter.format(
                amount: converted.amount,
                fractionDigits: converted.fractionLength
            )
            return showCurrency ? "\(formatted) \(currency)" : "\(formatted)"
        case let .jetton(jettonItem):
            guard let jettonRate = balanceStore.state[wallet]?.balance.jettonsBalance
                .first(where: { $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo })?
                .jettonBalance.rates[currency]
            else {
                return ""
            }

            let converted = rateConverter.convert(
                amount: amount,
                amountFractionLength: jettonItem.jettonInfo.fractionDigits,
                rate: jettonRate
            )
            let formatted = amountFormatter.format(
                amount: converted.amount,
                fractionDigits: converted.fractionLength
            )
            return showCurrency ? "\(formatted) \(currency)" : "\(formatted)"
        }
    }

    public func convertTronAmountToCurrency(
        token: TronToken,
        _ amount: BigUInt,
        _ showCurrency: Bool = true
    ) -> String {
        guard let rate = tronRate(token: token) else { return "" }
        let currency = currencyStore.state
        let converted = rateConverter.convert(amount: amount, amountFractionLength: token.fractionDigits, rate: rate)
        let formatted = amountFormatter.format(
            amount: converted.amount,
            fractionDigits: converted.fractionLength
        )
        return showCurrency ? "\(formatted) \(currency)" : "\(formatted)"
    }

    public func convertMultichainAmountToCurrency(
        asset: MultichainAsset,
        amount: BigUInt,
        showCurrency: Bool = true
    ) -> String {
        let currency = currencyStore.state
        let price = asset.price.prices[currency.code]
            ?? asset.price.prices[currency.code.lowercased()]
            ?? asset.price.prices[currency.code.uppercased()]
        guard let price else {
            return ""
        }

        let rate = Rates.Rate(
            currency: currency,
            rate: Decimal(price),
            diff24h: nil
        )
        let converted = rateConverter.convert(
            amount: amount,
            amountFractionLength: asset.asset.decimals,
            rate: rate
        )
        // Use the fiat accessory so UI shows a symbol instead of appending the currency code.
        return amountFormatter.format(
            amount: converted.amount,
            fractionDigits: converted.fractionLength,
            accessory: showCurrency ? .fiat(currency) : .none
        )
    }

    public func calculateRemaining(token: TonToken, tokenAmount: BigUInt, isSecure: Bool) -> Remaining {
        guard let balance = balanceStore.state[wallet]?.balance else {
            return .insufficient
        }
        let tokenBalance: BigUInt
        switch token {
        case .ton:
            tokenBalance = BigUInt(balance.tonBalance.tonBalance.amount)
        case let .jetton(jettonItem):
            let jettonBalance = balance.jettonsBalance.first(where: {
                $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo
            })?.jettonBalance

            tokenBalance = jettonBalance?.scaledBalance ?? jettonBalance?.quantity ?? 0
        }
        return calculateRemaining(
            amount: tokenAmount,
            balance: tokenBalance,
            fractionalDigits: token.fractionDigits,
            symbol: token.symbol,
            isSecure: isSecure
        )
    }

    public func calculateTronRemaining(token: TronToken, amount: BigUInt, isSecure: Bool) -> Remaining {
        guard let balance = tronBalance(token: token) else {
            return .insufficient
        }
        return calculateRemaining(
            amount: amount,
            balance: balance,
            fractionalDigits: token.fractionDigits,
            symbol: token.symbol,
            isSecure: isSecure
        )
    }

    public func formatMultichainBalance(
        asset: MultichainAsset,
        isSecure: Bool
    ) -> String {
        if isSecure {
            return .secureModeValue
        }
        return amountFormatter.format(
            amount: asset.balance,
            fractionDigits: asset.asset.decimals,
            accessory: asset.asset.symbol.isEmpty ? .none : .tokenSymbol(asset.asset.symbol)
        )
    }

    public func multichainTokenAmountFromCurrencyInput(
        asset: MultichainAsset,
        currencyInput: String
    ) -> BigUInt {
        let normalizedInput = AmountInputFormatter.normalizedString(
            currencyInput,
            decimalSeparator: "."
        ) ?? ""
        let decimalValue = Decimal(string: normalizedInput, locale: Locale(identifier: "en_US_POSIX")) ?? 0
        return convertFiatToMultichainTokenAmountWithCorrection(
            asset: asset,
            fiatValue: decimalValue
        )
    }

    public func convertFiatToMultichainTokenAmountWithCorrection(
        asset: MultichainAsset,
        fiatValue: Decimal
    ) -> BigUInt {
        let currency = currencyStore.state
        let price = asset.price.prices[currency.code]
            ?? asset.price.prices[currency.code.lowercased()]
            ?? asset.price.prices[currency.code.uppercased()]
        guard let price, price > 0 else { return 0 }

        let rate = Decimal(price)
        let fractionDigits = asset.asset.decimals
        let multiplier = pow(10, fractionDigits)
        let tokenAmountDecimal = (fiatValue / rate) * multiplier
        let accordingToBehavior = NSDecimalNumberHandler(
            roundingMode: .down,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        var tokenAmount = BigUInt((tokenAmountDecimal as NSDecimalNumber).rounding(accordingToBehavior: accordingToBehavior).stringValue) ?? 0

        let maxTokenAmount = asset.balance
        let maxFiatValue = (Decimal(string: maxTokenAmount.description) ?? 0) / multiplier * rate
        let isFiatValueWithinBalance = fiatValue <= maxFiatValue

        if isFiatValueWithinBalance, tokenAmount >= maxTokenAmount {
            return maxTokenAmount
        }

        while !isFiatValueWithinBalance || tokenAmount < maxTokenAmount {
            let fiatBack = (Decimal(string: tokenAmount.description) ?? 0) / multiplier * rate
            if fiatBack >= fiatValue { break }
            tokenAmount += 1
        }

        return tokenAmount
    }

    private func calculateRemaining(
        amount: BigUInt,
        balance: BigUInt,
        fractionalDigits: Int,
        symbol: String?,
        isSecure: Bool
    ) -> Remaining {
        if balance >= amount {
            let value: String = {
                if isSecure {
                    return .secureModeValue
                } else {
                    let remainingAmount = balance - amount
                    return amountFormatter.format(
                        amount: remainingAmount,
                        fractionDigits: fractionalDigits,
                        accessory: symbol.flatMap { .tokenSymbol($0) } ?? .none
                    )
                }
            }()

            return .remaining(value)
        } else {
            return .insufficient
        }
    }

    public func getMaximumAmount(token: TonToken) -> BigUInt {
        guard let balance = balanceStore.state[wallet]?.balance else {
            return .zero
        }
        switch token {
        case .ton:
            return BigUInt(balance.tonBalance.tonBalance.amount)
        case let .jetton(jettonItem):
            let jettonBalance = balance.jettonsBalance.first(where: {
                $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo
            })?.jettonBalance
            return jettonBalance?.scaledBalance ?? jettonBalance?.quantity ?? 0
        }
    }

    public func getTronMaximumAmount(token: TronToken) -> BigUInt {
        tronBalance(token: token) ?? .zero
    }

    private func tronBalance(token: TronToken) -> BigUInt? {
        guard let balance = balanceStore.state[wallet]?.balance else { return nil }
        switch token {
        case .usdt:
            return balance.tronUSDT?.amount
        case .trx:
            return balance.tronTRX?.amount
        }
    }

    private func tronRate(token: TronToken) -> Rates.Rate? {
        let currency = currencyStore.state
        let rates = switch token {
        case .usdt:
            tonRatesStore.state.usdtRates
        case .trx:
            tonRatesStore.state.jettonRates
                .first { $0.key.caseInsensitiveCompare(TronSwift.TRX.symbol) == .orderedSame }?
                .value ?? []
        }
        return rates.first { $0.currency == currency }
    }

    public func getCurrency() -> Currency {
        currencyStore.state
    }

    public enum CommentState {
        case ledgerNonAsciiError
        case ok
    }

    public func validateComment(comment: String) -> CommentState {
        if wallet.kind == .ledger && comment.count > 0 && !comment.containsOnlyAsciiCharacters {
            return .ledgerNonAsciiError
        }

        return .ok
    }

    public func convertFiatToTokenAmountWithCorrection(
        token: TonToken,
        fiatValue: Decimal,
        maxTokenAmount: BigUInt? = nil
    ) -> BigUInt {
        let currency = currencyStore.state
        let fractionDigits: Int
        let rate: Decimal?

        switch token {
        case .ton:
            fractionDigits = TonInfo.fractionDigits
            rate = tonRatesStore.state.tonRates.first(where: { $0.currency == currency })?.rate
        case let .jetton(jettonItem):
            fractionDigits = jettonItem.jettonInfo.fractionDigits
            rate = balanceStore.state[wallet]?.balance.jettonsBalance
                .first(where: { $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo })?
                .jettonBalance.rates[currency]?.rate
        }

        guard let rate, rate > 0 else { return 0 }

        let multiplier = pow(10, fractionDigits)
        let tokenAmountDecimal = (fiatValue / rate) * multiplier
        let accordingToBehavior = NSDecimalNumberHandler(
            roundingMode: .down,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        var tokenAmount = BigUInt((tokenAmountDecimal as NSDecimalNumber).rounding(accordingToBehavior: accordingToBehavior).stringValue) ?? 0

        if let maxTokenAmount, tokenAmount >= maxTokenAmount {
            return maxTokenAmount
        }

        while maxTokenAmount.map({ tokenAmount < $0 }) ?? true {
            let fiatBack = (Decimal(string: tokenAmount.description) ?? 0) / multiplier * rate
            if fiatBack >= fiatValue { break }
            tokenAmount += 1
        }

        return tokenAmount
    }

    public func convertCurrencyToTronAmountWithCorrection(
        token: TronToken,
        currencyValue: Decimal,
        maxTokenAmount: BigUInt? = nil
    ) -> BigUInt {
        let rate = tronRate(token: token)?.rate

        guard let rate, rate > 0 else { return 0 }

        let fractionDigits = token.fractionDigits
        let multiplier = pow(10, fractionDigits)
        let tokenAmountDecimal = (currencyValue / rate) * multiplier
        let accordingToBehavior = NSDecimalNumberHandler(
            roundingMode: .down,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        var tokenAmount = BigUInt((tokenAmountDecimal as NSDecimalNumber).rounding(accordingToBehavior: accordingToBehavior).stringValue) ?? 0

        if let maxTokenAmount, tokenAmount >= maxTokenAmount {
            return maxTokenAmount
        }

        while maxTokenAmount.map({ tokenAmount < $0 }) ?? true {
            let fiatBack = (Decimal(string: tokenAmount.description) ?? 0) / multiplier * rate
            if fiatBack >= currencyValue { break }
            tokenAmount += 1
        }
        return tokenAmount
    }

    public func tokenAmountFromCurrencyInput(
        token: TonToken,
        currencyInput: String
    ) -> BigUInt {
        let normalizedInput = AmountInputFormatter.normalizedString(
            currencyInput,
            decimalSeparator: "."
        ) ?? ""
        let decimalValue = Decimal(string: normalizedInput, locale: Locale(identifier: "en_US_POSIX")) ?? 0
        let maxTokenAmount = getMaximumAmount(token: token)
        return convertFiatToTokenAmountWithCorrection(
            token: token,
            fiatValue: decimalValue,
            maxTokenAmount: maxTokenAmount
        )
    }

    public func tronAmountFromCurrencyInput(token: TronToken, currencyInput: String) -> BigUInt {
        let normalizedInput = AmountInputFormatter.normalizedString(
            currencyInput,
            decimalSeparator: "."
        ) ?? ""
        let decimalValue = Decimal(string: normalizedInput, locale: Locale(identifier: "en_US_POSIX")) ?? 0
        return convertCurrencyToTronAmountWithCorrection(
            token: token,
            currencyValue: decimalValue,
            maxTokenAmount: getTronMaximumAmount(token: token)
        )
    }

    public func tokenAmountFromTokenInput(tokenInput: String, fractionDigits: Int) -> BigUInt {
        convertInputStringToAmount(
            input: tokenInput,
            targetFractionalDigits: fractionDigits
        ).amount
    }
}

private extension String {
    var containsOnlyAsciiCharacters: Bool {
        let pattern = "^[\\x20-\\x7E]*$"
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: self.utf16.count)
            let match = regex.firstMatch(in: self, options: [], range: range)
            return match != nil
        } catch {
            Log.w("Invalid regular expression: \(error.localizedDescription)")
            return false
        }
    }
}

extension String {
    static let secureModeValue = "* * *"
}
