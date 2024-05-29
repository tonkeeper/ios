import BigInt
import Foundation

public struct TokenConverterControllerModel {
    public var sendToken: Token?
    public var sendTokenBalance: String
    public var sendTokenAmount: String
    
    public var receiveToken: Token?
    public var receiveTokenBalance: String
    public var receiveTokenAmount: String
    
    public var isLoading = false
}

public class TokenConverterController {
    private(set) var model: TokenConverterControllerModel {
        didSet {
            didUpdateTokens?(model)
        }
    }

    private var currency: Currency
    private var rates: [String: TokenRate] = [:]

    public var shouldUpdateSendTokenInput: ((String) -> Void)?
    public var shouldUpdateReceiveTokenInput: ((String) -> Void)?
    public var didUpdateTokens: ((TokenConverterControllerModel) -> Void)?

    public let wallet: Wallet
    
    private let balanceStore: BalanceStore
    private let amountFormatter: AmountFormatter
    private let ratesService: RatesService

    init(
        wallet: Wallet,
        balanceStore: BalanceStore,
        amountFormatter: AmountFormatter,
        ratesService: RatesService,
        currency: Currency
    ) {
        self.model = .init(sendTokenBalance: "", sendTokenAmount: "", receiveTokenBalance: "", receiveTokenAmount: "", isLoading: false)

        self.currency = currency
        self.wallet = wallet
        self.balanceStore = balanceStore
        self.amountFormatter = amountFormatter
        self.ratesService = ratesService
    }
    
    // MARK: - Currency
    
    public static func currencyToken(currency: Currency) -> Token {
        let info = JettonInfo(address: .mock(workchain: 0, seed: ""), fractionDigits: 2, name: currency.title, symbol: currency.symbol, verification: .whitelist, imageURL: nil)
        return .jetton(.init(jettonInfo: info))
    }
    
    public static func currencyRate(currency: Currency) -> TokenRate {
        .init(rate: .init(currency: currency, rate: 1.0, diff24h: nil))
    }
    
    public func updateCurency(currency: Currency, completion: @escaping () -> Void) {
        if self.currency == currency { return }
        self.currency = currency
        model.isLoading = true
        updateRates(currency: currency) { [weak self] in
            self?.setSendInput("0")
            self?.setReceiveInput("0")
            self?.model.isLoading = false
            completion()
        }
    }

    // MARK: - Send

    public func getSendToken() -> Token {
        let emptyJettonInfo = JettonInfo.empty
        return model.sendToken ?? .jetton(.init(jettonInfo: emptyJettonInfo))
    }

    public func setSendToken(_ token: Token) {
        do {
            var editedModel = self.model

            if token == editedModel.receiveToken {
                editedModel.receiveToken = nil
                editedModel.receiveTokenBalance = ""
            }

            let sendTokenBalance = try balanceStore.getBalance(wallet: wallet).balance
            let sendTokenBalanceAmount: BigUInt
            switch token {
            case .ton:
                sendTokenBalanceAmount = BigUInt(sendTokenBalance.tonBalance.amount)
            case .jetton(let jettonItem):
                sendTokenBalanceAmount = sendTokenBalance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })?.quantity ?? 0
            }

            let formattedBalance = amountFormatter.formatAmount(
                sendTokenBalanceAmount,
                fractionDigits: token.tokenFractionDigits,
                maximumFractionDigits: token.tokenFractionDigits
            )

            editedModel.sendTokenBalance = "\(formattedBalance)"
            editedModel.sendToken = token

            editedModel.isLoading = true
            setReceiveInput("")
            shouldUpdateReceiveTokenInput?("")

            self.model = editedModel

            updateRates(currency: self.currency) { [weak self] in
                self?.model.isLoading = false
            }
        } catch {

        }
    }

    public func setSendInput(_ inputText: String) {
        if let sendToken = model.sendToken {
            let sendAmount = convertInputStringToAmount(
                input: inputText,
                targetFractionalDigits: sendToken.tokenFractionDigits
            )

            let formattedSendAmount = amountFormatter.formatAmount(
                sendAmount.amount,
                fractionDigits: sendToken.tokenFractionDigits,
                maximumFractionDigits: sendToken.tokenFractionDigits
            )

            if let receiveToken = model.receiveToken,
               let receiveRate = rates[receiveToken.tokenName],
               let sendRate = rates[sendToken.tokenName] {

                let receiveAmount = self.convertTokenAmountByRate(
                    fromToken: sendToken,
                    fromTokenRate: sendRate,
                    toToken: receiveToken,
                    toTokenRate: receiveRate,
                    amount: sendAmount.amount
                )

                let formattedReceiveAmount = amountFormatter.formatAmount(
                    receiveAmount.0,
                    fractionDigits: receiveAmount.1,
                    maximumFractionDigits: 2
                )

                model.receiveTokenAmount = formattedReceiveAmount
                shouldUpdateReceiveTokenInput?(formattedReceiveAmount)
            }

            model.sendTokenAmount = formattedSendAmount
        }
    }

    // MARK: - Receive

    public func setReceiveToken(_ token: Token) {
        do {
            var editedModel = self.model

            let receiveTokenBalance = try balanceStore.getBalance(wallet: wallet).balance
            let receiveTokenBalanceAmount: BigUInt
            switch token {
            case .ton:
                receiveTokenBalanceAmount = BigUInt(receiveTokenBalance.tonBalance.amount)
            case .jetton(let jettonItem):
                receiveTokenBalanceAmount = receiveTokenBalance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })?.quantity ?? 0
            }
            
            let formattedBalance = amountFormatter.formatAmount(
                receiveTokenBalanceAmount,
                fractionDigits: token.tokenFractionDigits,
                maximumFractionDigits: token.tokenFractionDigits
            )
            
            editedModel.receiveTokenBalance = formattedBalance
            editedModel.receiveToken = token

            editedModel.isLoading = true
            setSendInput("")
            shouldUpdateSendTokenInput?("")

            self.model = editedModel

            updateRates(currency: self.currency) { [weak self] in
                self?.model.isLoading = false
            }
        } catch {

        }
    }

    public func setReceiveInput(_ inputText: String) {
        if let receiveToken = model.receiveToken {
            let receiveAmount = convertInputStringToAmount(
                input: inputText,
                targetFractionalDigits: receiveToken.tokenFractionDigits
            )
            
            let formattedReceiveAmount = amountFormatter.formatAmount(
                receiveAmount.amount,
                fractionDigits: receiveToken.tokenFractionDigits,
                maximumFractionDigits: receiveToken.tokenFractionDigits
            )

            if let sendToken = model.sendToken,
               let sendRate = rates[sendToken.tokenName],
               let receiveRate = rates[receiveToken.tokenName] {

                let sendAmount = self.convertTokenAmountByRate(
                    fromToken: receiveToken,
                    fromTokenRate: receiveRate,
                    toToken: sendToken,
                    toTokenRate: sendRate,
                    amount: receiveAmount.amount
                )

                let formattedSendAmount = amountFormatter.formatAmount(
                    sendAmount.0,
                    fractionDigits: sendAmount.1,
                    maximumFractionDigits: 2
                )

                model.sendTokenAmount = formattedSendAmount
                shouldUpdateSendTokenInput?(formattedSendAmount)
            }

            model.receiveTokenAmount = formattedReceiveAmount
        }
    }

    // MARK: - Swap

    public func swapTokens() {
        var editedModel = self.model

        let sendToken = editedModel.sendToken
        let receiveToken = editedModel.receiveToken

        let sendTokenBalance = editedModel.sendTokenBalance
        let receiveTokenBalance = editedModel.receiveTokenBalance

        let sendTokenAmount = editedModel.sendTokenAmount
        let receiveTokenAmount = editedModel.receiveTokenAmount

        editedModel.receiveToken = sendToken
        editedModel.receiveTokenBalance = sendTokenBalance
        editedModel.receiveTokenAmount = sendTokenAmount

        editedModel.sendToken = receiveToken
        editedModel.sendTokenBalance = receiveTokenBalance
        editedModel.sendTokenAmount = receiveTokenAmount

        shouldUpdateSendTokenInput?(receiveTokenAmount)
        shouldUpdateReceiveTokenInput?(sendTokenAmount)

        self.model = editedModel
    }

    // MARK: - Max
    
    private var isMax = false
    
    public func setMax() {
        setSendInput(model.sendTokenBalance)
        shouldUpdateSendTokenInput?(model.sendTokenBalance)
    }
    
    public func setMin() {
        setSendInput("0")
        shouldUpdateSendTokenInput?("0")
    }

    public func toggleMax() {
        isMax.toggle()
        if isMax {
            setMax()
        } else {
            setMin()
        }
    }
    
    // MARK: - Get
    
    public func getModel() -> TokenConverterControllerModel {
        model
    }
    
    public func getSendInputAmount() -> BigUInt? {
        if let sendToken = model.sendToken {
            return convertInputStringToAmount(
                input: model.sendTokenAmount,
                targetFractionalDigits: sendToken.tokenFractionDigits
            ).amount
        }
        return nil
    }
    
    public func getReceiveInputAmount() -> BigUInt? {
        if let receiveToken = model.receiveToken {
            return convertInputStringToAmount(
                input: model.receiveTokenAmount,
                targetFractionalDigits: receiveToken.tokenFractionDigits
            ).amount
        }
        return nil
    }
}

private extension TokenConverterController {
     func convertTokenAmountByRate(
        fromToken: Token,
        fromTokenRate: TokenRate,
        toToken: Token,
        toTokenRate: TokenRate,
        amount: BigUInt
    ) -> (BigUInt, Int) {
        if toTokenRate.rate.rate.isZero {
            return (0, 2)
        }

        let toTokenBigInt = toTokenRate.ratePlainBigInt
        let toTokenNormalizeBigInt: BigUInt = toTokenRate.rateNormalizedBigInt

        let fromTokenBigInt = fromTokenRate.ratePlainBigInt
        let fromTokenNormalizeBigInt: BigUInt = fromTokenRate.rateNormalizedBigInt

        let result = amount * toTokenNormalizeBigInt * fromTokenBigInt / toTokenBigInt / fromTokenNormalizeBigInt

        return (result, fromToken.tokenFractionDigits)
    }

    func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
        let input = input.replacingOccurrences(of: " ", with: "")
        guard !input.isEmpty else { return (0, targetFractionalDigits) }
        let fractionalSeparator: String = .fractionalSeparator ?? ""
        let components = input.components(separatedBy: fractionalSeparator)
        guard components.count < 3 else {
            return (0, targetFractionalDigits)
        }

        var fractionalDigits = 0
        if components.count == 2 {
            let fractionalString = components[1]
            fractionalDigits = fractionalString.count
        }
        let zeroString = String(repeating: "0", count: max(0, targetFractionalDigits - fractionalDigits))
        let bigIntValue = BigUInt(stringLiteral: components.joined() + zeroString)
        return (bigIntValue, targetFractionalDigits)
    }

    func updateRates(currency: Currency, completion: (() -> Void)?) {
        let receiveToken = model.receiveToken?.jettonInfo
        let jettons = [receiveToken].compactMap { $0 }

        Task { [weak self] in
            guard let self else { return }
            
            self.handleUpdatedRates(
                self.ratesService.getRates(jettons: jettons),
                currentCurrency: currency,
                completion: completion
            )

            let ratesResponse = try await self.ratesService.loadRates(jettons: jettons, currencies: [currency])
            
            self.handleUpdatedRates(
                ratesResponse,
                currentCurrency: currency,
                completion: completion
            )
        }
    }
    
    func handleUpdatedRates(_ ratesResponse: Rates, currentCurrency: Currency, completion: (() -> Void)?) {
        let tonRate = ratesResponse.ton.first(where: { $0.currency == currentCurrency })

        var resultRates: [String: TokenRate] = [:]

        if let tonRate {
            resultRates[TonInfo.name] = .init(rate: tonRate)
        }

        for jettonsRate in ratesResponse.jettonsRates {
            if let rate = jettonsRate.rates.first(where: { $0.currency == currentCurrency }) {
                resultRates[jettonsRate.jettonInfo.name] = .init(rate: rate)
            }
        }
        
        let currencyToken = Self.currencyToken(currency: self.currency)
        let currencyRate = Self.currencyRate(currency: self.currency)
        resultRates[currencyToken.tokenName] = currencyRate

        completion?()
        self.rates = resultRates
    }
}

private extension String {
    static var fractionalSeparator: String? {
        Locale.current.decimalSeparator
    }
}
