import Foundation

public enum BuySellConfirmationType {
    case sell
    case buy
}

public final class ConfirmationInputController: TokenConverterController {    
    public var didUpdateModel: ((Model) -> Void)?
    
    init(
        ratesService: RatesService,
        balanceStore: BalanceStore,
        amountFormatter: AmountFormatter,
        wallet: Wallet
    ) {
        super.init(
            wallet: wallet,
            balanceStore: balanceStore,
            amountFormatter: amountFormatter,
            ratesService: ratesService,
            currency: .USD
        )
        
        didUpdateTokens = { [weak self] model in
            guard let self else { return }
            
            let tokenAmount = model.sendTokenAmount
            let tokenSymbol = model.sendToken?.tokenSym
            let tokenFractionDigits = model.sendToken?.tokenFractionDigits
            
            let currencyAmount = model.receiveTokenAmount
            let currencySymbol = model.receiveToken?.tokenSym
            let currencyFractionDigits = model.receiveToken?.tokenFractionDigits
            
            let model = Model(
                tokenAmount: tokenAmount,
                tokenSymbol: tokenSymbol,
                tokenFractionDigits: tokenFractionDigits,
                currencyAmount: currencyAmount,
                currencySymbol: currencySymbol,
                currencyFractionDigits: currencyFractionDigits,
                isLoading: model.isLoading
            )
            self.didUpdateModel?(model)
        }
    }
    
    public override func swapTokens() {}
}

public extension ConfirmationInputController {
    struct Model {
        public let tokenAmount: String?
        public let tokenSymbol: String?
        public let tokenFractionDigits: Int?
        
        public let currencyAmount: String?
        public let currencySymbol: String?
        public let currencyFractionDigits: Int?
        
        public let isLoading: Bool
    }
}
