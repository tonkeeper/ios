//
//  SwapMainViewModel.swift
//  TonUI
//
//  Created by Marina on 20.05.2024.
//

import Foundation
import KeeperCore
import BigInt
import TonSwift

class SwapMainViewModel : ObservableObject {
    
    enum ContainerType : String {
        case send
        case receive
    }
    
    enum ScreenState {
        /// Initial state
        case sendToken
        case sendAmount
        case receiveToken
        /// After all the input is entered
        case loading
        /// Continue
        case proceed
        case confirm
        
        var buttonTitle: String {
            switch self {
            case .sendToken, .receiveToken: "Choose Token"
            case .sendAmount: "Enter Amount"
            case .loading: ""
            case .proceed: "Continue"
            case .confirm: "Confirm"
            }
        }
        var disablesEdition: Bool {
            switch self {
            case .sendToken, .sendAmount, .receiveToken, .loading, .proceed: false
            case .confirm: true
            }
        }
        var toolbarTitle: String {
            switch self {
            case .sendToken, .sendAmount, .receiveToken, .loading, .proceed: "Swap"
            case .confirm: "Confirm Swap"
            }
        }
    }
    
    // Sheets presented variables
    @Published var showSettings: Bool = false
    @Published var showChoose: Bool = false
    @Published var showPopover: Bool = false
    @Published var popoverText: String = ""
    // Swap main variables
    @Published var screenState: ScreenState = .sendToken
    @Published var sendCurrency: CurrencyModel? = nil
    @Published var receiveCurrency: CurrencyModel? = nil
    @Published var sendAmountStr: String = ""
    @Published var receiveAmountStr: String = ""
    // Choose search variables
    @Published var searchText = ""
    @Published var previousSearchText = ""
    // Change currency variables
    @Published var chooseDialogCalledFor: SwapMainViewModel.ContainerType = .send
    @Published var chosenNewCurrency: CurrencyModel? = nil
    
    @Published var priceImpact: String = ""
    @Published var minimumRecived: String = ""
    @Published var liquidityProviderFee: String = ""
    @Published var blockchainFee: String = "0.008 - 0.025 TON"
    @Published var route: String = ""
    @Published var provider: String = "STON.fi"
    @Published var exchangeRate: String? = nil
    
    @Published var errorMessage: String? = nil
    
    /// Currencies received from API
    @Published var allCurrencies: [CurrencyModel]  = []
    /// Currencies, filtered by search
    @Published var searchedCurrencies: [CurrencyModel] = []
    /// Currencies, shown on screen, first 100 of searched
    @Published var shownCurrencies: [CurrencyModel] = []
    /// Suggested currencies, counted in ViewModel
    @Published var suggestedCurrencies: [CurrencyModel] = []
    
    @Published var isBalanceValid: Bool = true
    
    var slippageSelected: String = UserDefaults.standard.string(forKey: "SwapSlippageValue") ?? "1"
    var closeAction: (() -> Void)?
    var swapConfirmationHandler: (() async -> Bool)?
    private var didSendTransactionToken: NSObjectProtocol?
    private var balanceCurrencies: [CurrencyModel]  = []
    
    private var balance: Balance?
    private var rates: Rates?
    private let wallet: Wallet
    private let balanceController: BalanceWidgetController
    private let sendingConfirmationController: KeeperCore.SendConfirmationController
    private let apiWorker = StonFIApiWorker()
    
    init(wallet: Wallet,
         keeperCoreAssembly: KeeperCore.Assembly,
         mainAssembly: KeeperCore.MainAssembly) {
        self.wallet = wallet
        self.balanceController = keeperCoreAssembly.widgetAssembly().balanceWidgetController()
        self.sendingConfirmationController = mainAssembly.sendConfirmationController(wallet: wallet)
        
        setupObservers()
        loadBalance()
    }
    
    private func setupObservers() {
        didSendTransactionToken = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("didSendTransaction"),
            object: nil,
            queue: .main) { [weak self] _ in
                self?.closeAction?()
            }
    }
    
    func close() {
        closeAction?()
    }
    
    func backButtonAction() {
        
        if errorMessage != nil {
            return
        }
        
        switch screenState {
        case .sendToken:
            chooseDialogCalledFor = .send
            chosenNewCurrency = nil
            showChoose.toggle()
        case .sendAmount:
            updateState(onlyInputStatesMoveOn: false)
        case .receiveToken:
            chooseDialogCalledFor = .receive
            chosenNewCurrency = nil
            showChoose.toggle()
        case .loading:
            updateState(onlyInputStatesMoveOn: false)
        case .proceed:
            updateState(onlyInputStatesMoveOn: false)
        case .confirm:
            break
        }
    }
    
    func search(searchText: String) {
        if previousSearchText.count > 0 && !searchText.contains(previousSearchText) {
            searchedCurrencies = allCurrencies
            shownCurrencies = Array(searchedCurrencies.prefix(100))
        }
        guard searchText.count > 0 else { return }
        searchedCurrencies = searchedCurrencies.filter( { $0.symbol.lowercased().contains(searchText.lowercased()) || $0.fullName.lowercased().contains(searchText.lowercased())})
        shownCurrencies = Array(searchedCurrencies.prefix(100))
        previousSearchText = searchText
    }
    
    func saveChosenCurrency() {
        switch chooseDialogCalledFor {
        case .send:
            if let chosenNewCurrency {
                sendCurrency = chosenNewCurrency
                if sendCurrency == receiveCurrency {
                    receiveCurrency = nil
                }
                updateState(onlyInputStatesMoveOn: ![.sendToken, .sendAmount, .receiveToken].contains(screenState))
            }
        case .receive:
            if let chosenNewCurrency {
                receiveCurrency = chosenNewCurrency
                if sendCurrency == receiveCurrency {
                    sendCurrency = nil
                }
                updateState(onlyInputStatesMoveOn: ![.sendToken, .sendAmount, .receiveToken].contains(screenState))
            }
        }
    }
    
    private func loadBalance() {
        let address = try? wallet.identity.identifier().string
        Task {
            do {
                self.rates = try await balanceController.getRate(currency: .USD)
                self.balance = try await balanceController
                    .loadAllTokensBalance(walletIdentifier: address,
                                          currency: Currency.TON)
                guard let balance else { return }
                self.balanceCurrencies = mapBalance(balance)
                self.loadAssets()
            } catch {
                self.loadAssets()
                print("\(error)")
            }
        }
    }
    
    private func loadAssets() {
        apiWorker.fetchAssets { result in
            switch result {
            case .success(let assets):
                var currenciesDictionary: [Address: CurrencyModel] = [:]
                
                for currency in self.balanceCurrencies {
                    if let jettonAddress = currency.jetton?.jettonInfo.address,
                       let verification = currency.jetton?.jettonInfo.verification,
                       verification == .whitelist {
                        currenciesDictionary[jettonAddress] = currency
                    }
                }
                
                for asset in assets {
                    guard !asset.community else { continue }
                    if let address = try? Address.parse(asset.contractAddress) {
                        let jetton = JettonInfo(address: address,
                                                fractionDigits: asset.decimals,
                                                name: asset.displayName,
                                                symbol: asset.symbol,
                                                verification: .whitelist,
                                                imageURL: nil)
                        
                        let jettonItem = JettonItem(jettonInfo: jetton, walletAddress: address)
                        
                        let currency = CurrencyModel(symbol: asset.symbol,
                                                     fullName: asset.displayName,
                                                     balance: "0",
                                                     dollarBalance: "0",
                                                     logo: URL(string: asset.imageUrl ?? ""),
                                                     jetton: jettonItem)
                        
                        if currency.symbol == TonInfo.symbol,
                           let ton = self.balanceCurrencies.first(where: { $0.symbol == TonInfo.symbol }) {
                            let tonCurrency = CurrencyModel(symbol: currency.symbol,
                                                            fullName: currency.fullName,
                                                            balance: ton.balance,
                                                            dollarBalance: ton.dollarBalance,
                                                            logo: currency.logo,
                                                            jetton: currency.jetton)
                            currenciesDictionary[address] = tonCurrency
                        } else if currenciesDictionary[address] != nil {
                            if currency.balance != "0" {
                                currenciesDictionary[address] = currency
                            }
                        } else {
                            currenciesDictionary[address] = currency
                        }
                    }
                }
                
                var currencies = Array(currenciesDictionary.values)
                currencies.sort {
                    if $0.symbol == TonInfo.symbol {
                        return true
                    } else if $1.symbol == TonInfo.symbol {
                        return false
                    } else {
                        return $0.balance != "0" && $1.balance == "0"
                    }
                }
                
                DispatchQueue.main.async {
                    self.allCurrencies = currencies
                    self.searchedCurrencies = currencies
                    self.shownCurrencies = Array(currencies.prefix(100))
                    // TODO: Which ones should the app recommend?
                    self.suggestedCurrencies = Array(currencies.prefix(3))
                }
            case .failure(let error):
                print("Failed to fetch assets: \(error)")
            }
        }
    }
    
    private func mapBalance(_ balance: Balance) -> [CurrencyModel] {
        var mappedCurrencies: [CurrencyModel] = []
        
        if balance.tonBalance.amount > 0 {
            let quantity = formatBalance(balance.tonBalance.amount)
            let decimalQuantity = decimalFromQuantity(quantity)
            let price = rates?.ton[0].rate ?? 0
            let fiatPrice = formatDecimal(price * decimalQuantity,
                                          maxFractionDigits: 2,
                                          minFractionDigits: 2) ?? ""
            
            mappedCurrencies.append(CurrencyModel(symbol: TonInfo.symbol,
                                                  fullName: TonInfo.name,
                                                  balance: quantity,
                                                  dollarBalance: fiatPrice,
                                                  logo: nil,
                                                  jetton: nil)
            )
        }
        
        balance.jettonsBalance.forEach { jettonBalance in
            let quantity = formatBalance(Int64(jettonBalance.quantity))
            let decimalQuantity = decimalFromQuantity(quantity)
            let price = jettonBalance.rates[.USD]?.rate ?? 0
            let fiatPrice = formatDecimal(price * decimalQuantity,
                                          maxFractionDigits: 2,
                                          minFractionDigits: 2) ?? ""
            
            mappedCurrencies.append(CurrencyModel(symbol: jettonBalance.item.jettonInfo.symbol ?? "",
                                                  fullName: jettonBalance.item.jettonInfo.name,
                                                  balance: formatBalance(Int64(jettonBalance.quantity)),
                                                  dollarBalance: fiatPrice,
                                                  logo: jettonBalance.item.jettonInfo.imageURL,
                                                  jetton: jettonBalance.item)
            )
        }
        return mappedCurrencies
    }
    
    
    
    private func updateErrorMessage(_ message: String?) {
        DispatchQueue.main.async {
            self.errorMessage = message
        }
    }
    
    
    func updateScreenState(_ state: ScreenState) {
        DispatchQueue.main.async {
            self.screenState = state
        }
    }
    
    func updateState(onlyInputStatesMoveOn: Bool) {
        guard self.sendCurrency != nil else {
            updateScreenState(.sendToken)
            return
        }
        guard sendAmountStr.count > 0 else {
            updateScreenState(.sendAmount)
            return
        }
        guard receiveCurrency != nil else {
            updateScreenState(.receiveToken)
            return
        }
        // If this line is reached, then all the input is entered correctly
        // After that only .next and later states are available
        if onlyInputStatesMoveOn {
            if !screenState.disablesEdition {
                updateScreenState(.proceed)
            }
        } else {
            switch screenState {
            case .loading:
                updateScreenState(.proceed)
            case .proceed:
                showPopover = false
                updateScreenState(.confirm)
            case .confirm:
                break
            default:
                updateScreenState(.loading)
            }
        }
    }
    
    func sendRequestEmulated() {
        // TODO: add reverse swap
        
        Task {
            if sendAmountStr == "0" || sendAmountStr == "0." {
                DispatchQueue.main.async {
                    self.receiveAmountStr = "0"
                    self.updateErrorMessage(nil)
                    self.updateScreenState(.sendAmount)
                }
                return
            }
            
            guard let sendCurrency,
                  let sendJetton = sendCurrency.jetton,
                  let receiveCurrency,
                  let receiveJetton = receiveCurrency.jetton,
                  let units = convertUnitsToSend(sendAmountStr) else { return }
            
            let swapRequest = StonFISwapRequest(
                offerAddress: sendJetton.jettonInfo.address.toString(),
                askAddress: receiveJetton.jettonInfo.address.toString(),
                units: units,
                slippageTolerance: convertSlippage(slippageSelected) ?? "0.001"
            )
            
            if screenState != .proceed {
                updateScreenState(.loading)
            }
            
            apiWorker.simulateSwap(swapRequest: swapRequest) { result in
                switch result {
                case .success(let swapResult):
                    guard let receivedAmount =  swapResult.askUnits,
                          let receivedAmountStr = self.convertReceivedAmount(receivedAmount),
                          let priceImpact = swapResult.priceImpact,
                          let minAskUnits = swapResult.minAskUnits,
                          let fee = swapResult.feeUnits,
                          let feeSymbol = receiveJetton.jettonInfo.symbol
                    else {
                        self.updateErrorMessage("Swap simulation error")
                        return
                    }
                    DispatchQueue.main.async {
                        self.receiveAmountStr = receivedAmountStr
                        self.updateScreenState(.proceed)
                        
                        self.checkBalance()
                        
                        self.exchangeRate = swapResult.swapRate ?? "0"
                        self.priceImpact = self.convertPriceImpact(priceImpact) ?? "0"
                        self.minimumRecived = self.convertReceivedAmount(minAskUnits) ?? "0"
                        self.liquidityProviderFee = (self.convertLiquidityProviderFee(fee) ?? "") + " " + feeSymbol
                        self.route = sendCurrency.symbol + " » " + receiveCurrency.symbol
                    }
                case .failure:
                    self.updateErrorMessage("Swap simulation error")
                }
            }
        }
    }
    
    func confirmSwapTransaction() {
        Task {
            let isConfirmed = await swapConfirmationHandler?() ?? false
            guard isConfirmed else { return false }
            executeSwap()
            return true
        }
    }
    
    private func executeSwap() {
        guard let amount = self.convertAmountForSwap(input: self.sendAmountStr),
              let minimalAsk = getMinimalAskAmount() else { return }
        Task {
            do {
                if sendCurrency?.symbol == TonInfo.symbol,
                   let recieveJetton = receiveCurrency?.jetton {
                    await sendingConfirmationController.startSwapTon(
                        recievingItem: SendItem.token(Token.jetton(recieveJetton),
                                                      amount: BigUInt(amount)),
                        minimalSwapAskAmount: BigUInt(minimalAsk))
                }
                else if receiveCurrency?.symbol == TonInfo.symbol,
                        let sendJetton = sendCurrency?.jetton {
                    await sendingConfirmationController.startSwapJetton(
                        sendingItem: SendItem.token(Token.jetton(sendJetton),
                                                    amount: BigUInt(amount)),
                        minimalSwapAskAmount: BigUInt(minimalAsk))
                } else if let recieveJetton = receiveCurrency?.jetton,
                          let sendJetton = sendCurrency?.jetton {
                    await sendingConfirmationController.startSwapJettons(
                        sendingItem: SendItem.token(Token.jetton(sendJetton),
                                                    amount: BigUInt(amount)),
                        recievingItem: SendItem.token(Token.jetton(recieveJetton),
                                                      amount: BigUInt(amount)),
                        minimalSwapAskAmount: BigUInt(minimalAsk))
                }
                
                try await sendingConfirmationController.sendSwapTransaction()
            } catch {
                print(error)
            }
        }
    }
}
extension SwapMainViewModel {
    
    func checkBalance() {
        guard let sendCurrency,
              let inputValue = convertBalance(input: sendAmountStr),
              inputValue > 0,
              let balance = convertBalance(input: sendCurrency.balance) else { return }
        if balance < inputValue {
            updateErrorMessage("Insufficient Balance")
        } else {
            updateErrorMessage(nil)
        }
    }
    
    private func convertBalance(input: String) -> Decimal? {
        let cleanedInput = input.replacingOccurrences(of: " ", with: "")
        let standardizedInput = cleanedInput.replacingOccurrences(of: ",", with: ".")
        
        guard let decimalValue = Decimal(string: standardizedInput) else {
            print("Invalid decimal string")
            return nil
        }
        
        return decimalValue
    }
    
    private func formatBalance(_ amount: Int64) -> String {
        return balanceController
            .formatBalance(amount)
    }
    
    private func decimalFromQuantity(_ quantity: String) -> Decimal {
        var string = quantity.replacingOccurrences(of: ",", with: ".")
        string = string.replacingOccurrences(of: " ", with: "")
        return Decimal(string: string) ?? 0
    }
    
    private func standardizedDecimalString(from input: String) -> String? {
        let cleanedInput = input.replacingOccurrences(of: " ", with: "")
        return cleanedInput.replacingOccurrences(of: ",", with: ".")
    }
    
    private func formatDecimal(_ decimal: Decimal, maxFractionDigits: Int, minFractionDigits: Int) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = minFractionDigits
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = ""
        
        return formatter.string(from: decimal as NSDecimalNumber)
    }
    
    private func performOperationOnDecimal(input: String, operation: (Decimal) -> Decimal, maxFractionDigits: Int, minFractionDigits: Int) -> String? {
        guard let standardizedInput = standardizedDecimalString(from: input),
              let decimalValue = Decimal(string: standardizedInput) else {
            print("Invalid decimal string")
            return nil
        }
        
        let resultValue = operation(decimalValue)
        return formatDecimal(resultValue, maxFractionDigits: maxFractionDigits, minFractionDigits: minFractionDigits)
    }
    
    private func convertUnitsToSend(_ input: String) -> String? {
        return performOperationOnDecimal(input: input, operation: { $0 * 1_000_000_000 }, maxFractionDigits: 0, minFractionDigits: 0)
    }
    
    private func convertReceivedAmount(_ input: String) -> String? {
        return performOperationOnDecimal(input: input, operation: { $0 / 1_000_000_000 }, maxFractionDigits: 9, minFractionDigits: 9)
    }
    
    private func convertSlippage(_ input: String) -> String? {
        return performOperationOnDecimal(input: input, operation: { $0 / 100 }, maxFractionDigits: 9, minFractionDigits: 9)
    }
    
    private func convertPriceImpact(_ input: String) -> String? {
        return performOperationOnDecimal(input: input, operation: { $0 * 100 }, maxFractionDigits: 2, minFractionDigits: 0)
    }
    
    private func convertLiquidityProviderFee (_ input: String) -> String? {
        return performOperationOnDecimal(input: input, operation: { $0 / 1_000_000_000 }, maxFractionDigits: 4, minFractionDigits: 0)
    }
    
    private func convertAmountForSwap(input: String) -> Int? {
        guard let standardizedInput = standardizedDecimalString(from: input),
              let decimalValue = Decimal(string: standardizedInput) else {
            print("Invalid decimal string")
            return nil
        }
        
        let multipliedValue = decimalValue * 1_000_000_000
        let intValue = NSDecimalNumber(decimal: multipliedValue).intValue
        
        return intValue
    }
    
    private func getMinimalAskAmount() -> Int? {
        guard let intAmount = self.convertAmountForSwap(input: self.receiveAmountStr),
              let slippagePercent = Double(self.slippageSelected) else { return nil }
        let amount = Double(intAmount)
        let percentageAmount = Int(amount * (slippagePercent / 100))
        
        return intAmount - percentageAmount
    }
}
