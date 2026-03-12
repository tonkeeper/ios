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

    init(
        wallet: Wallet,
        balanceStore: ConvertedBalanceStore,
        dnsService: DNSService,
        tonRatesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        recipientResolver: RecipientResolver,
        amountFormatter: AmountFormatter,
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
    }

    public func resolveRecipient(input: String) async throws -> Recipient {
        try await recipientResolver.resolverRecipient(string: input, network: wallet.network)
    }

    public func convertInputStringToAmount(
        input: String,
        targetFractionalDigits: Int
    ) -> (amount: BigUInt, fraction: Int) {
        guard !input.isEmpty else { return (0, 0) }

        let fractionalSeparator = Locale.current.decimalSeparator ?? "."
        let components = input.components(separatedBy: fractionalSeparator)

        guard components.count < 3 else { return (0, 0) }

        let fraction = components.count == 2 ? components[1] : ""
        // Truncate fraction to target length if needed
        let truncatedFraction = fraction.count > targetFractionalDigits
            ? String(fraction.prefix(targetFractionalDigits))
            : fraction
        let zeroString = String(repeating: "0", count: max(0, targetFractionalDigits - truncatedFraction.count))
        let joined = components[0] + (components.count == 2 ? truncatedFraction : "") + zeroString
        let amount = BigUInt(joined) ?? 0

        return (amount, min(fraction.count, targetFractionalDigits))
    }

    public func convertAmountToInputString(
        amount: BigUInt,
        fractionDigits: Int,
        symbol: String? = nil
    ) -> String {
        let formatted = amountFormatter.format(
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

    public func isTronUSDTAmountAvailableToSend(amount: BigUInt) -> Bool {
        guard let balance = balanceStore.state[wallet]?.balance else { return false }
        guard let tronUSDTBalance = balance.tronUSDT else { return false }

        return tronUSDTBalance.amount >= amount
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

    public func convertTronUSDTAmountToCurrency(
        _ amount: BigUInt,
        _ showCurrency: Bool = true
    ) -> String {
        let currency = currencyStore.state
        guard let rate = tonRatesStore.state.usdtRates.first(where: { $0.currency == currency }) else { return "" }
        let converted = rateConverter.convert(amount: amount, amountFractionLength: TronSwift.USDT.fractionDigits, rate: rate)
        let formatted = amountFormatter.format(
            amount: converted.amount,
            fractionDigits: converted.fractionLength
        )
        return showCurrency ? "\(formatted) \(currency)" : "\(formatted)"
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

    public func calculateTronUSDTRemaining(amount: BigUInt, isSecure: Bool) -> Remaining {
        guard let balance = balanceStore.state[wallet]?.balance.tronUSDT else {
            return .insufficient
        }
        return calculateRemaining(
            amount: amount,
            balance: balance.amount,
            fractionalDigits: TronSwift.USDT.fractionDigits,
            symbol: TronSwift.USDT.symbol,
            isSecure: isSecure
        )
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
                        accessory: symbol.flatMap { .symbol($0) } ?? .none
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

    public func getTronUSDTMaximumAmount() -> BigUInt {
        guard let balance = balanceStore.state[wallet]?.balance.tronUSDT else {
            return .zero
        }
        return balance.amount
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

        while true {
            let fiatBack = (Decimal(string: tokenAmount.description) ?? 0) / multiplier * rate
            if fiatBack >= fiatValue { break }
            tokenAmount += 1
            if let maxTokenAmount, tokenAmount > maxTokenAmount { break }
        }

        return tokenAmount
    }

    public func convertCurrencyToTronUSDTAmountWithCorrection(
        currencyValue: Decimal,
        maxTokenAmount: BigUInt? = nil
    ) -> BigUInt {
        let currency = currencyStore.state
        let rate = tonRatesStore.state.usdtRates.first(where: { $0.currency == currency })?.rate

        guard let rate, rate > 0 else { return 0 }

        let fractionDigits = TronSwift.USDT.fractionDigits
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

        while true {
            let fiatBack = (Decimal(string: tokenAmount.description) ?? 0) / multiplier * rate
            if fiatBack >= currencyValue { break }
            tokenAmount += 1
            if let maxTokenAmount, tokenAmount > maxTokenAmount { break }
        }
        return tokenAmount
    }

    public func tokenAmountFromCurrencyInput(
        token: TonToken,
        currencyInput: String
    ) -> BigUInt {
        let decimalValue = Decimal(string: currencyInput.replacingOccurrences(of: ",", with: ".")) ?? 0
        let maxTokenAmount = getMaximumAmount(token: token)
        return convertFiatToTokenAmountWithCorrection(
            token: token,
            fiatValue: decimalValue,
            maxTokenAmount: maxTokenAmount
        )
    }

    public func tronUSDTAmountFromCurrencyInput(currencyInput: String) -> BigUInt {
        let decimalValue = Decimal(string: currencyInput.replacingOccurrences(of: ",", with: ".")) ?? 0
        let maxTokenAmount = getTronUSDTMaximumAmount()
        return convertCurrencyToTronUSDTAmountWithCorrection(
            currencyValue: decimalValue,
            maxTokenAmount: maxTokenAmount
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
    static let groupSeparator = Locale.current.groupingSeparator
    static let fractionalSeparator = Locale.current.decimalSeparator

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
