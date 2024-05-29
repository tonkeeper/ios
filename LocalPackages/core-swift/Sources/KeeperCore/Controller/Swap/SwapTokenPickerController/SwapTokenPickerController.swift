import Foundation
import BigInt

public final class SwapTokenPickerController {
  
  public struct TokenModel {
    public let image: TokenImage
    public let identifier: String
    public let symbol: String
    public let name: String
    public let balance: String
    public let balanceInBaseCurrency: String
  }
  
  public var didUpdateTokens: (([TokenModel], [TokenModel]) -> Void)?
  public var didUpdateSelectedTokenIndex: ((Int) -> Void)?
  
  private var suggestedTokens = [SwapToken]()
  private var tokens = [SwapToken]()

  private let wallet: Wallet
  private let selectedToken: SwapToken?
  private let selectedPairToken: SwapToken?
  private let walletBalanceStore: WalletBalanceStore
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let assetsStore: AssetsStore
  private let amountFormatter: AmountFormatter
  
  init(wallet: Wallet,
       selectedToken: SwapToken?,
       selectedPairToken: SwapToken?,
       walletBalanceStore: WalletBalanceStore,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       assetsStore: AssetsStore,
       amountFormatter: AmountFormatter) {
    self.wallet = wallet
    self.selectedToken = selectedToken
    self.selectedPairToken = selectedPairToken
    self.walletBalanceStore = walletBalanceStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.assetsStore = assetsStore
    self.amountFormatter = amountFormatter
  }
  
  public func start() async {
    _ = await walletBalanceStore.addEventObserver(self) { observer, event in
      switch event {
      case .balanceUpdate(_, let wallet):
        guard (try? wallet.friendlyAddress) == (try? observer.wallet.friendlyAddress) else {
          return
        }
        Task { await observer.reloadTokens() }
      }
    }
    await reloadTokens()
  }
  
  public func getTokenAt(index: Int) -> SwapToken {
    guard tokens.count > index else { return .ton }
    return tokens[index]
  }
  
  public func isTokenSelectedAt(index: Int) -> Bool {
    guard tokens.count > index else { return false }
    return selectedToken == tokens[index]
  }
  
  public func getSuggestedTokenAt(index: Int) -> SwapToken {
    guard suggestedTokens.count > index else { return .ton }
    return suggestedTokens[index]
  }
  
  private func getTonBalanceInBaseCurrency(amount: Int64) async -> String {
    guard amount > 1 else { return "" }
    let currency = await currencyStore.getActiveCurrency()
    guard let rate = await tonRatesStore.getTonRates().first(where: { $0.currency == currency }) else { return ""}
    let converted = RateConverter().convert(amount: amount, amountFractionLength: TonInfo.fractionDigits, rate: rate)
    let formatted = await amountFormatter.formatAmount(
      converted.amount,
      fractionDigits: converted.fractionLength,
      maximumFractionDigits: 2,
      currency: currencyStore.getActiveCurrency()
    )
    return formatted
  }

  private func getJettonBalanceInBaseCurrency(jettonInfo: JettonInfo, amount: BigUInt, rates: [Currency: Rates.Rate]) async -> String {
    guard !amount.isZero else { return "" }
    let currency = await currencyStore.getActiveCurrency()
    guard let rate = rates[currency] else { return ""}
    let converted = RateConverter().convert(amount: amount, amountFractionLength: jettonInfo.fractionDigits, rate: rate)
    let formatted = amountFormatter.formatAmount(
      converted.amount,
      fractionDigits: converted.fractionLength,
      maximumFractionDigits: 2,
      currency: currency
    )
    return formatted
  }
  
  private var currentSearchTask: Task<Void, Never>?
  public func search(text keyword: String) async {
    currentSearchTask?.cancel()
    currentSearchTask = Task {
      let balance: Balance
      do {
        balance = try await walletBalanceStore.getBalanceState(wallet: wallet).walletBalance.balance
      } catch {
        balance = Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [])
      }
      
      var assetList = await assetsStore.getAssets()
      let pairsDictionary = await assetsStore.getPairs() ?? [:]
      for (i, asset) in (assetList ?? []).enumerated() {
        assetList?[i].isSwappable = pairsDictionary[asset.contractAddress ?? ""] != nil
      }
      let assets = assetList?.filter({ asset in
        var isAvailable = true
        if let selectedPairToken {
          switch selectedPairToken {
          case .ton:
            isAvailable = pairsDictionary[Asset.toncoin.contractAddress ?? ""]?.contains(where: { str in
              str == asset.contractAddress ?? ""
            }) ?? false
            break
          case .jetton(let selectedAsset):
            isAvailable = pairsDictionary[selectedAsset.contractAddress ?? ""]?.contains(where: { str in
              str == asset.contractAddress ?? ""
            }) ?? false
          }
        }
        return isAvailable &&
        asset.isSwappable &&
        asset.symbol != "TON" &&
        !balance.jettonsBalance.contains { token in
          token.item.jettonInfo.symbol == asset.symbol
        } && (keyword.isEmpty ||
              asset.symbol.lowercased().contains(keyword) ||
              asset.displayName.lowercased().contains(keyword))
      })
      
      let allowedJettonBalances = balance.jettonsBalance.filter({ [weak self] jettonBalance in
        guard let self else {return true}
        guard let selectedPairToken else {return assetList?.contains(where: { asset in
          asset.contractAddress == jettonBalance.item.jettonInfo.address.toString() &&
          (keyword.isEmpty ||
           asset.symbol.lowercased().contains(keyword) ||
           asset.displayName.lowercased().contains(keyword))
        }) ?? false}
        // check if jetton can be selected and also is a search match
        switch selectedPairToken {
        case .ton:
          return (pairsDictionary[Asset.toncoin.contractAddress ?? ""]?.contains(where: { str in
            return str == jettonBalance.item.jettonInfo.address.toString() &&
            (keyword.isEmpty ||
             (jettonBalance.item.jettonInfo.symbol?.lowercased().contains(keyword) ?? false) ||
             jettonBalance.item.jettonInfo.name.lowercased().contains(keyword))
          }) ?? false)
        case .jetton(let asset):
          return (pairsDictionary[asset.contractAddress ?? ""]?.contains(where: { str in
            return str == jettonBalance.item.jettonInfo.address.toString() &&
            (keyword.isEmpty ||
             (jettonBalance.item.jettonInfo.symbol?.lowercased().contains(keyword) ?? false) ||
             jettonBalance.item.jettonInfo.name.lowercased().contains(keyword))
          }) ?? false)
        }
      })
      
      var isTonAvailable = keyword.isEmpty ||
      keyword.lowercased().contains("ton") ||
      keyword.lowercased().contains("toncoin")
      if isTonAvailable {
        // check if ton can be selected
        if let selectedPairToken {
          switch selectedPairToken {
          case .ton:
            isTonAvailable = false
          case .jetton(let asset):
            isTonAvailable = pairsDictionary[asset.contractAddress ?? ""]?.contains(where: { str in
              return str == Asset.toncoin.contractAddress
            }) ?? false
          }
        }
      }
      let tonSwapTokenArray: [SwapToken] = isTonAvailable ? [SwapToken.ton] : []
      
      let _tokens = tonSwapTokenArray + allowedJettonBalances.map { SwapToken.jetton(Asset(jettonInfo: $0.item.jettonInfo)) } + (assets?.map({ asset in
        return SwapToken.jetton(asset)
      }) ?? [])
      await MainActor.run {
        self.tokens = _tokens
      }
      
      let tonFormattedBalance = amountFormatter.formatAmount(
        BigUInt(balance.tonBalance.amount),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2,
        symbol: TonInfo.symbol
      )
      
      let tonModel = await TokenModel(
        image: .ton,
        identifier: "Toncoin",
        symbol: TonInfo.symbol,
        name: TonInfo.name,
        balance: tonFormattedBalance,
        balanceInBaseCurrency: getTonBalanceInBaseCurrency(amount: balance.tonBalance.amount)
      )
      
      var _jettonModels = [TokenModel]()
      for jettonBalance in allowedJettonBalances {
        let formattedBalance = amountFormatter.formatAmount(
          jettonBalance.quantity,
          fractionDigits: jettonBalance.item.jettonInfo.fractionDigits,
          maximumFractionDigits: 2,
          symbol: jettonBalance.item.jettonInfo.symbol
        )
        _jettonModels.append(
          TokenModel(
            image: .url(jettonBalance.item.jettonInfo.imageURL),
            identifier: jettonBalance.item.jettonInfo.address.toRaw(),
            symbol: jettonBalance.item.jettonInfo.symbol ?? "",
            name: jettonBalance.item.jettonInfo.name,
            balance: formattedBalance,
            balanceInBaseCurrency: await getJettonBalanceInBaseCurrency(jettonInfo: jettonBalance.item.jettonInfo,
                                                                        amount: jettonBalance.quantity,
                                                                        rates: jettonBalance.rates)
          )
        )
      }
      let jettonModels = _jettonModels
      
      let notOwnedModels: Array<SwapTokenPickerController.TokenModel> = assets?.map({ asset in
        return TokenModel(image: .url(URL(string: asset.imageUrl)),
                          identifier: asset.contractAddress ?? "",
                          symbol: asset.symbol,
                          name: asset.displayName,
                          balance: "",
                          balanceInBaseCurrency: "0")
      }) ?? []
      
      suggestedTokens = tokens.filter({ swapToken in
        switch swapToken {
        case .jetton(let asset):
          return asset.symbol == "jUSDT" || asset.symbol == "ANON"
        default:
          return false
        }
      })
      let suggestedTokenModels = suggestedTokens.map({ swapToken in
        switch swapToken {
        case .ton:
          fatalError()
        case .jetton(let asset):
          return TokenModel(image: .url(URL(string: asset.imageUrl)),
                            identifier: asset.contractAddress ?? "",
                            symbol: asset.symbol,
                            name: asset.displayName,
                            balance: "",
                            balanceInBaseCurrency: "0")
        }
      })
      let tonSwapModelArray: [TokenModel] = isTonAvailable ? [tonModel] : []
      
      await MainActor.run {
        didUpdateTokens?(suggestedTokenModels, tonSwapModelArray + jettonModels + notOwnedModels)
        
        /*switch selectedToken {
         case .ton:
         didUpdateSelectedTokenIndex?(0)
         case .jetton(let jettonItem):
         guard let index = balance.jettonsBalance.firstIndex(where: { $0.item == jettonItem }) else { return }
         didUpdateSelectedTokenIndex?(index + 1)
         }*/
      }
    }
  }
}

private extension SwapTokenPickerController {
  func reloadTokens() async {
    await search(text: "")
  }
}
