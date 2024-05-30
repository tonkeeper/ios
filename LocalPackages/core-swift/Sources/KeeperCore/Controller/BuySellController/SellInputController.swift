import Foundation

public final class SellInputController: TokenConverterController {
    private let currencyStore: CurrencyStore
    
    public var didUpdateModel: ((Model) -> Void)?
    public var isTokenInput = true
    
    init(
        ratesService: RatesService,
        balanceStore: BalanceStore,
        currencyStore: CurrencyStore,
        amountFormatter: AmountFormatter,
        wallet: Wallet
    ) {
        self.currencyStore = currencyStore
                
        super.init(
            wallet: wallet,
            balanceStore: balanceStore,
            amountFormatter: amountFormatter,
            ratesService: ratesService,
            currency: .USD
        )
        
        setSendToken(.ton)
        setReceiveToken(Self.currencyToken(currency: .USD))
        setSendInput("0")
        
        didUpdateTokens = { [weak self] model in
            guard let self else { return }
            
            let tokenAmount = model.sendTokenAmount
            let tokenSymbol = model.sendToken?.tokenSym
            let tokenFractionDigits = model.sendToken?.tokenFractionDigits
            
            let currencyAmount = model.receiveTokenAmount
            let currencySymbol = model.receiveToken?.tokenSym
            let currencyFractionDigits = model.receiveToken?.tokenFractionDigits
            
            let remainAmount: Double
            let remainSymbol: String
            if self.isTokenInput {
                let sendTokenAmount = model.sendTokenAmount.toDouble()
                let sendTokenBalance = model.sendTokenBalance.toDouble()
                remainAmount = (sendTokenBalance ?? 0) - (sendTokenAmount ?? 0)
                remainSymbol = tokenSymbol ?? ""
            } else {
                let receiveTokenAmount = model.receiveTokenAmount.toDouble()
                let receiveTokenBalance = model.receiveTokenBalance.toDouble()
                remainAmount = (receiveTokenBalance ?? 0) - (receiveTokenAmount ?? 0)
                remainSymbol = currencySymbol ?? ""
            }
            let remainFractionDigits = max(5, remainAmount.exponent)
            let remainString = String(format: "%.\(remainFractionDigits)f", remainAmount)
            
            let state: State
            if tokenAmount == "0" || tokenAmount.isEmpty {
                state = .enterAmount(available: remainString + " " + remainSymbol)
            } else if remainAmount < 0 {
                state = .insufficientBalance
            } else {
                state = .remaining(available: remainString + " " + remainSymbol)
            }
            
            let model = Model(
                tokenAmount: tokenAmount,
                tokenSymbol: tokenSymbol,
                tokenFractionDigits: tokenFractionDigits,
                currencyAmount: currencyAmount,
                currencySymbol: currencySymbol,
                currencyFractionDigits: currencyFractionDigits,
                state: state
            )
            self.didUpdateModel?(model)
        }
    }
    
    public func start() {
        Task { [weak self] in
            if let currency = await self?.currencyStore.getActiveCurrency() {
                if currency != .TON {
                    self?.updateCurency(currency: currency) {
                        self?.setReceiveToken(Self.currencyToken(currency: currency))
                    }
                }
            }
            
        }
    }
    
    public override func swapTokens() {
        isTokenInput.toggle()
        super.swapTokens()
    }
}

public extension SellInputController {
    enum State {
        case remaining(available: String)
        case enterAmount(available: String)
        case insufficientBalance
    }
    
    struct Model {
        public let tokenAmount: String?
        public let tokenSymbol: String?
        public let tokenFractionDigits: Int?
        
        public let currencyAmount: String?
        public let currencySymbol: String?
        public let currencyFractionDigits: Int?
        
        public let state: State
    }
}

private extension String {
    func toDouble() -> Double? {
        let doubleString = self.replacingOccurrences(by: [
            " " : "",
            "," : "."
        ])
        return Double(doubleString)
    }
}

private extension String {
    func replacingOccurrences(by rules: [String: String]) -> String {
        reduce(into: "") {
            if let replacedCharacter = rules[String($1)] {
                $0 += replacedCharacter
            } else {
                $0 += String($1)
            }
        }
    }
}
