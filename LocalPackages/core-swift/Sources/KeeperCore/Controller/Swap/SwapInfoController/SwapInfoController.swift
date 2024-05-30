import Foundation
import BigInt
import Combine
import TonSwift

public enum SwapInfoModelState: Equatable {
    case insufficientBalance(symbol: String)
    case chooseToken
    case enterAmount
    case `continue`
}

public struct SwapInfoModel {
    public struct TransactionModel {
        public let priceImpact: String?
        public let minimumReceived: String?
        public let providerFee: String?
        public let blockchainFee: String?
        public let route: String?
        public let provider: String?
        
        public let minAskAmountRaw: BigUInt?
        public let offerAmountRaw: BigUInt?
        
        public init(
            priceImpact: String? = nil,
            minimumReceived: String? = nil,
            providerFee: String? = nil,
            blockchainFee: String? = nil,
            route: String? = nil,
            provider: String? = nil,
            minAskAmountRaw: BigUInt? = nil,
            offerAmountRaw: BigUInt? = nil
        ) {
            self.priceImpact = priceImpact
            self.minimumReceived = minimumReceived
            self.providerFee = providerFee
            self.blockchainFee = blockchainFee
            self.route = route
            self.provider = provider
            
            self.minAskAmountRaw = minAskAmountRaw
            self.offerAmountRaw = offerAmountRaw
        }
    }
    
    public var sendToken: Token?
    public var sendTokenBalance: String
    public var sendTokenAmount: String
    
    public var receiveToken: Token?
    public var receiveTokenBalance: String
    public var receiveTokenAmount: String
    
    public var transactionModel: TransactionModel?
    
    public var isLoading = false
}

public extension SwapInfoModel {
    var state: SwapInfoModelState {
        let containsSendToken = sendToken != nil
        let containsReceiveToken = receiveToken != nil
        let containsAmount = !(sendTokenAmount.isEmpty || sendTokenAmount == "0")
        let isInsufficient = sendTokenAmount > sendTokenBalance
        
        if isInsufficient, let sendToken {
            return .insufficientBalance(symbol: sendToken.tokenSym)
        } else if !containsSendToken || !containsReceiveToken {
            return .chooseToken
        } else if !containsAmount {
            return .enterAmount
        } else {
            return .continue
        }
    }
}

public final class SwapInfoController {
    public private(set) var model: SwapInfoModel {
        didSet {
            didUpdateModel?(model)
            if oldValue.receiveTokenAmount != model.receiveTokenAmount || oldValue.sendTokenAmount != model.sendTokenAmount {
                updateTransactionInfo(delay: 0.5)
            }
            updateTransaction()
        }
    }
    
    public var tolerance: Int = 0 {
        didSet {
            updateTransactionInfo(delay: 0.0)
        }
    }
    
    private var rates: [String: TokenRate] = [:]
    
    public var shouldUpdateSendTokenInput: ((String) -> Void)?
    public var shouldUpdateReceiveTokenInput: ((String) -> Void)?
    
    public var didUpdateSendToken: ((Token?) -> Void)?
    public var didUpdateReceiveToken: ((Token?) -> Void)?
    
    public var didUpdateModel: ((SwapInfoModel) -> Void)?
    
    public let wallet: Wallet
    private let balanceStore: BalanceStore
    private let amountFormatter: AmountFormatter
    private let ratesService: RatesService
    private let rateConverter: RateConverter
    private let stonfiService: StonfiService
    
    init(
        wallet: Wallet,
        balanceStore: BalanceStore,
        amountFormatter: AmountFormatter,
        ratesService: RatesService,
        rateConverter: RateConverter,
        stonfiService: StonfiService
    ) {
        self.model = .init(sendTokenBalance: "", sendTokenAmount: "", receiveTokenBalance: "", receiveTokenAmount: "", isLoading: false)
        
        self.wallet = wallet
        self.balanceStore = balanceStore
        self.amountFormatter = amountFormatter
        self.ratesService = ratesService
        self.rateConverter = rateConverter
        self.stonfiService = stonfiService
    }
    
    deinit {
        debounceTransactionPublisher?.invalidate()
        debounceTransactionInfoPublisher?.invalidate()
        debounceTransactionPublisher = nil
        debounceTransactionInfoPublisher = nil
    }
    
    public func start() {
        setSendToken(.ton)
    }
    
    public func forceUpdate() {
        didUpdateModel?(model)
    }
    
    public func containsTokenInWallet(token: Token) -> Bool {
        do {
            let balance = try balanceStore.getBalance(wallet: wallet).balance
            switch token {
            case .ton:
                return true
            case .jetton(let jettonItem):
                return balance.jettonsBalance.contains(where: { $0.item.jettonInfo == jettonItem.jettonInfo })
            }
        } catch {
            return false
        }
    }

    // MARK: - Send

    public func getSendToken() -> Token? {
        return model.sendToken
    }
    
    public func getSendAmount() -> BigUInt? {
        if let sendToken = model.sendToken {
            return convertInputStringToAmount(
                input: model.sendTokenAmount,
                targetFractionalDigits: sendToken.tokenFractionDigits
            ).amount
        }
        return nil
    }

    public func setSendToken(_ token: Token) {
        do {
            var editedModel = self.model

            if token.tokenName == editedModel.receiveToken?.tokenName {
                editedModel.receiveToken = nil
                editedModel.sendTokenBalance = "0"
                editedModel.receiveTokenBalance = ""
                didUpdateReceiveToken?(nil)
            }

            let sendTokenBalance = try balanceStore.getBalance(wallet: wallet).balance
            let sendTokenBalanceAmount: BigUInt
            switch token {
            case .ton:
                sendTokenBalanceAmount = BigUInt(sendTokenBalance.tonBalance.amount)
            case .jetton(let jettonItem):
                sendTokenBalanceAmount = sendTokenBalance.jettonsBalance.first(where: {
                    $0.item.jettonInfo.name == jettonItem.jettonInfo.name &&
                    $0.item.jettonInfo.symbol == jettonItem.jettonInfo.symbol
                })?.quantity ?? 0
            }

            let formattedBalance = amountFormatter.formatAmount(
                sendTokenBalanceAmount,
                fractionDigits: token.tokenFractionDigits,
                maximumFractionDigits: token.tokenFractionDigits
            )

            editedModel.sendTokenBalance = formattedBalance
            editedModel.sendTokenAmount = "0"
            editedModel.sendToken = token

            editedModel.isLoading = true
            setReceiveInput("0")
            shouldUpdateReceiveTokenInput?("0")
            didUpdateSendToken?(editedModel.sendToken)

            self.model = editedModel

            updateRates { [weak self] in
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
    
    public func getReceiveToken() -> Token? {
        return model.receiveToken
    }
    
    public func getReceiveAmount() -> BigUInt? {
        if let receiveToken = model.receiveToken {
            return convertInputStringToAmount(
                input: model.receiveTokenAmount,
                targetFractionalDigits: receiveToken.tokenFractionDigits
            ).amount
        }
        return nil
    }

    public func setReceiveToken(_ token: Token) {
        do {
            var editedModel = self.model
            
            if token.tokenName == editedModel.sendToken?.tokenName {
                editedModel.sendToken = nil
                editedModel.sendTokenAmount = "0"
                editedModel.sendTokenBalance = "0"
                didUpdateSendToken?(nil)
            }

            let receiveTokenBalance = try balanceStore.getBalance(wallet: wallet).balance
            let receiveTokenBalanceAmount: BigUInt
            switch token {
            case .ton:
                receiveTokenBalanceAmount = BigUInt(receiveTokenBalance.tonBalance.amount)
            case .jetton(let jettonItem):
                receiveTokenBalanceAmount = receiveTokenBalance.jettonsBalance.first(where: {
                    $0.item.jettonInfo.name == jettonItem.jettonInfo.name &&
                    $0.item.jettonInfo.symbol == jettonItem.jettonInfo.symbol
                })?.quantity ?? 0
            }
            
            let formattedBalance = amountFormatter.formatAmount(
                receiveTokenBalanceAmount,
                fractionDigits: token.tokenFractionDigits,
                maximumFractionDigits: token.tokenFractionDigits
            )
            
            editedModel.receiveTokenBalance = formattedBalance
            editedModel.sendTokenAmount = "0"
            editedModel.receiveToken = token

            editedModel.isLoading = true
            setSendInput("0")
            shouldUpdateSendTokenInput?("0")
            didUpdateReceiveToken?(editedModel.receiveToken)

            self.model = editedModel

            updateRates { [weak self] in
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

    public func toggleMax() {
        setSendInput(model.sendTokenBalance)
        shouldUpdateSendTokenInput?(model.sendTokenBalance)
    }
    
    // MARK: - Transaction
    
    private var debounceTransactionInfoPublisher: Timer?
        
    private func updateTransactionInfo(delay: Double) {
        let state = model.state
        if state != .continue {
            debounceTransactionInfoPublisher = nil
            model.transactionModel = nil
            return
        }
        debounceTransactionInfoPublisher?.invalidate()
        debounceTransactionInfoPublisher = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            if let token0 = self.getSendToken(),
               let token1 = self.getReceiveToken() {
                var sendAddress: Address?
                var receiveAddress: Address?
                let amount = self.getSendAmount()
                
                switch (token0, token1) {
                case (.ton, .ton):
                    break
                case let (.jetton(jettonInfo0), .jetton(jettonInfo1)):
                    sendAddress = jettonInfo0.walletAddress
                    receiveAddress = jettonInfo1.walletAddress
                case let (.ton, .jetton(jettonInfo)):
                    sendAddress = TonInfo.tokenAddress
                    receiveAddress = jettonInfo.walletAddress
                case let (.jetton(jettonInfo), .ton):
                    sendAddress = jettonInfo.walletAddress
                    receiveAddress = TonInfo.tokenAddress
                }
                if let sendAddress, let receiveAddress, let amount, amount != BigUInt(stringLiteral: "0") {
                    self.model.isLoading = true
                    self.model.transactionModel = .init()
                    Task {
                        var editedModel = self.model
                        let tolerancePercent = Double(self.tolerance) / 100
                        if let result = try? await self.stonfiService.simulateSwap(
                            sendAddress: sendAddress,
                            receiveAddress: receiveAddress,
                            amount: amount,
                            tolerance: tolerancePercent
                        ) {
                            let minimumReceivedAmount = self.amountFormatter.formatAmount(
                                BigUInt(stringLiteral: result.minAskUnits),
                                fractionDigits: token1.tokenFractionDigits,
                                maximumFractionDigits: token1.tokenFractionDigits
                            )
                            let providerFee = self.amountFormatter.formatAmount(
                                BigUInt(stringLiteral: result.feeUnits),
                                fractionDigits: token1.tokenFractionDigits,
                                maximumFractionDigits: token1.tokenFractionDigits
                            )
                            let transactionModel = SwapInfoModel.TransactionModel(
                                priceImpact: result.priceImpact + " %",
                                minimumReceived: minimumReceivedAmount + " \(token1.tokenSym)",
                                providerFee: providerFee + " \(token1.tokenSym)",
                                blockchainFee: "0.11 - 0.17 TON",
                                route: "\(token0.tokenSym) » \(token1.tokenSym)",
                                provider: "STON.fi",
                                minAskAmountRaw: BigUInt(stringLiteral: result.minAskUnits),
                                offerAmountRaw: BigUInt(stringLiteral: result.offerUnits)
                            )
                            editedModel.transactionModel = transactionModel
                        }
                        editedModel.isLoading = false
                        self.model = editedModel
                    }
                }
            }
        }
    }
    
    private var debounceTransactionPublisher: Timer?
    
    private func updateTransaction() {
        if model.state != .continue {
            debounceTransactionPublisher?.invalidate()
            debounceTransactionPublisher = nil
            return
        }
        guard debounceTransactionPublisher == nil else { return }
        debounceTransactionPublisher = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            if let sendTokenAmount = self?.model.sendTokenAmount {
                self?.model.isLoading = true
                self?.updateRates { [weak self] in
                    self?.setSendInput(sendTokenAmount)
                    self?.model.isLoading = false
                }
            }
        }
    }
}

public extension SwapInfoController {
    func getSwapModel() -> SwapModel? {
        guard let token0 = model.sendToken, let token1 = model.receiveToken else {
            return nil
        }
        
        var swapType: SendItem.SwapType?
        
        switch (token0, token1) {
        case (.ton, .ton):
            break
        case let (.ton, .jetton(jettonInfo)):
            if let offerAmount = model.transactionModel?.offerAmountRaw {
                let to = jettonInfo.walletAddress
                swapType = .tonJetton(to: to, minAskAmount: .init(stringLiteral: "0"), offerAmount: offerAmount)
            }
        case let (.jetton(jettonInfo), .ton):
            if let offerAmount = model.transactionModel?.offerAmountRaw {
                let from = jettonInfo.walletAddress
                swapType = .jettonTon(from: from, minAskAmount: .init(stringLiteral: "0"), offerAmount: offerAmount)
            }
        case (.jetton(let jettonInfo0), .jetton(let jettonInfo1)):
            if let offerAmount = model.transactionModel?.offerAmountRaw {
                let from = jettonInfo0.walletAddress
                let to = jettonInfo1.walletAddress
                swapType = .jettonJetton(from: from, to: to, minAskAmount: .init(stringLiteral: "0"), offerAmount: offerAmount)
            }
        }
        
        guard let swapType else {
            return nil
        }
        
        return SwapModel(
            wallet: wallet,
            recipient: .init(recipientAddress: .raw(token0.address ?? .mock(workchain: 0, seed: "")), isMemoRequired: false),
            swapType: swapType
        )
    }
}

private extension SwapInfoController {
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
        let toTokenNormalizeBigInt = toTokenRate.rateNormalizedBigInt

        let fromTokenBigInt = fromTokenRate.ratePlainBigInt
        let fromTokenNormalizeBigInt = fromTokenRate.rateNormalizedBigInt

        let result = amount * toTokenNormalizeBigInt * fromTokenBigInt / toTokenBigInt / fromTokenNormalizeBigInt

        return (result, toToken.tokenFractionDigits)
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

    func updateRates(completion: (() -> Void)?) {
        let sendToken = model.sendToken?.jettonInfo
        let receiveToken = model.receiveToken?.jettonInfo
        let jettons = [sendToken, receiveToken].compactMap { $0 }

        Task { [weak self] in
            guard let self else { return }

            let ratesResponse = try await self.ratesService.loadRates(jettons: jettons, currencies: [Currency.TON])
            let tonRate = ratesResponse.ton.first(where: { $0.currency == .TON })

            var resultRates: [String: TokenRate] = [:]

            if let tonRate {
                resultRates[TonInfo.name] = .init(rate: tonRate)
            }

            for jettonsRate in ratesResponse.jettonsRates {
                if let rate = jettonsRate.rates.first(where: { $0.currency == .TON }) {
                    resultRates[jettonsRate.jettonInfo.name] = .init(rate: rate)
                }
            }

            completion?()
            self.rates = resultRates
        }
    }
}

private extension String {
    static var fractionalSeparator: String? {
        Locale.current.decimalSeparator
    }
}

extension JettonItem {
    public static let empty = JettonItem(
        jettonInfo: .init(address: .mock(workchain: 0, seed: ""), fractionDigits: 2, name: "", symbol: "", verification: .whitelist, imageURL: nil)
    )
}

extension JettonInfo {
    public static let empty = JettonInfo(
        address: .mock(workchain: 0, seed: ""),
        fractionDigits: 0,
        name: "",
        symbol: nil,
        verification: .blacklist,
        imageURL: nil
    )
}
