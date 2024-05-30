import Foundation
import BigInt
import TonSwift

public enum AssetKind {
  case ton
  case jetton
  case unknown
  
  public init(fromString rawValue: String) {
    switch rawValue.lowercased() {
    case "ton":
      self = .ton
    case "jetton":
      self = .jetton
    default:
      self = .unknown
    }
  }
  
  public func toString() -> String {
    switch self {
    case .ton:
      return "Ton"
    case .jetton:
      return "Jetton"
    case .unknown:
      return ""
    }
  }
}

struct AssetBalance {
  let assetSymbol: String
  let amount: String
  let convertedAmount: String?
}

public final class SwapTokenListController {
  
  public var didUpdateListItems: ((TokenButtonListItemsModel, SwapTokenListItemsModel) -> Void)?
  public var didUpdateSearchResultsItems: ((SwapTokenListItemsModel) -> Void)?
  
  private var tokenListItems: [SwapTokenListItemsModel.Item] = []
  
  private let wallet: Wallet
  private var contractAddressForPair = ""
  
  private let stonfiAssetsStore: StonfiAssetsStore
  private let stonfiPairsStore: StonfiPairsStore
  private let ratesStore: RatesStore
  private let currencyStore: CurrencyStore
  private let walletsStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let stonfiMapper: StonfiMapper
  private let swapTokenListMapper: SwapTokenListMapper

  init(stonfiAssetsStore: StonfiAssetsStore,
       stonfiPairsStore: StonfiPairsStore,
       ratesStore: RatesStore,
       currencyStore: CurrencyStore,
       walletsStore: WalletsStore,
       walletBalanceStore: WalletBalanceStore,
       stonfiMapper: StonfiMapper,
       swapTokenListMapper: SwapTokenListMapper) {
    self.stonfiAssetsStore = stonfiAssetsStore
    self.stonfiPairsStore = stonfiPairsStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.walletsStore = walletsStore
    self.walletBalanceStore = walletBalanceStore
    self.stonfiMapper = stonfiMapper
    self.swapTokenListMapper = swapTokenListMapper
    self.wallet = walletsStore.activeWallet
  }
  
  public func start(contractAddressForPair: Address?) async {
    self.contractAddressForPair = contractAddressForPair?.toString() ?? ""
    await updateListItems()
  }
  
  public func updateListItems() async {
    let assets = await stonfiAssetsStore.getAssets()
    await assetsDidUpdate(assets)
  }
  
  public func performSearch(with query: String) {
    guard !query.isEmpty else { return }
    let tokenListItems = self.tokenListItems
    
    Task {
      let lowercasedQuery = query.lowercased()
      let searchResults = tokenListItems
        .filter { item in
          let matchesSymbol = item.symbol.lowercased().contains(lowercasedQuery)
          let matchesDisplayName = item.displayName.lowercased().contains(lowercasedQuery)
          return matchesSymbol || matchesDisplayName
        }
      
      let tokenListItemsModel = SwapTokenListItemsModel(items: searchResults)
      
      await MainActor.run {
        didUpdateSearchResultsItems?(tokenListItemsModel)
      }
    }
  }
}

private extension SwapTokenListController {
  func assetsDidUpdate(_ assets: StonfiAssets) async {
    let pairs = await stonfiPairsStore.getPairs()
    let assetsBalanceDict = await getAssetsBalanceDict()
    
    let tokenListItems: [SwapTokenListItemsModel.Item] = assets.items
      .filter { asset in
        guard !contractAddressForPair.isEmpty else { return true }
        return pairs.hasPair(keyOne: asset.contractAddress, keyTwo: contractAddressForPair)
      }
      .compactMap { stonfiAsset in
        guard let swapAsset = stonfiMapper.mapStonfiAsset(stonfiAsset) else { return nil }
        let assetBalanceList = assetsBalanceDict[swapAsset.kind]
        let assetBalance = assetBalanceList?.first(where: { $0.assetSymbol == swapAsset.symbol })
        var tokenListItem = swapTokenListMapper.mapSwapAsset(swapAsset)
        tokenListItem.amount = assetBalance?.amount
        tokenListItem.convertedAmount = assetBalance?.convertedAmount
        return tokenListItem
      }
      .sorted(by: { $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending })
      .tokenListSorted()
    
    let suggestedTokenListItemsModel = createSuggestedTokenListModel(from: tokenListItems)
    let otherTokenListItemsModel = SwapTokenListItemsModel(items: tokenListItems)
    
    await MainActor.run {
      self.tokenListItems = tokenListItems
      didUpdateListItems?(suggestedTokenListItemsModel, otherTokenListItemsModel)
    }
  }
  
  func createSuggestedTokenListModel(from tokenListItems: [SwapTokenListItemsModel.Item]) -> TokenButtonListItemsModel {
    let items = tokenListItems
      .filter { suggestedTokenSymbols.contains($0.symbol) }
      .map { swapTokenListMapper.mapTokenListItem($0) }
    
    return TokenButtonListItemsModel(items: items)
  }
  
  func getAssetsBalanceDict() async -> [AssetKind : [AssetBalance]] {
    let walletBalanceState = try? await walletBalanceStore.getBalanceState(wallet: wallet)
    
    let balance: Balance
    if let walletBalance = walletBalanceState?.walletBalance {
      balance = walletBalance.balance
    } else {
      balance = Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [])
    }
    
    let jettons = balance.jettonsBalance.map({ $0.item.jettonInfo })
    let rates = ratesStore.getRates(jettons: jettons)
    
    let currency = await currencyStore.getActiveCurrency()
    
    return swapTokenListMapper.mapBalance(
      balance: balance,
      rates: rates,
      currency: currency
    )
  }
  
  var suggestedTokenSymbols: [String] {
    [TonInfo.symbol, "USD₮", "ANON"]
  }
}

private extension Array where Element == SwapTokenListItemsModel.Item {
  func tokenListSorted() -> [SwapTokenListItemsModel.Item] {
    return self.sorted { (leftItem: SwapTokenListItemsModel.Item, rightItem: SwapTokenListItemsModel.Item) -> Bool in
      // Place TON at first position
      if leftItem.symbol == .tonSymbol && leftItem.kind == .ton {
        return true
      } else if rightItem.symbol == .tonSymbol && rightItem.kind == .ton {
        return false
      }
      
      // Sort Ton kind by amount
      if leftItem.kind == .ton && leftItem.amount != nil {
        if rightItem.kind != .ton || rightItem.amount == nil {
          return true
        }
      } else if rightItem.kind == .ton && rightItem.amount != nil {
        return false
      }
      
      // Sort by USDT symbol
      if leftItem.symbol == .usdtSymbol || leftItem.symbol == .jusdtSymbol {
        if leftItem.symbol == .usdtSymbol {
          return true
        } else if rightItem.symbol != .usdtSymbol && rightItem.symbol != .jusdtSymbol {
          return true
        }
      } else if rightItem.symbol == .usdtSymbol || rightItem.symbol == .jusdtSymbol {
        return false
      }
      
      // Sort any kind by amount
      if leftItem.amount != nil {
        if rightItem.amount == nil {
          return true
        }
      } else if rightItem.amount != nil {
        return false
      }
      
      return leftItem.symbol.localizedStandardCompare(rightItem.symbol) == .orderedAscending
    }
  }
}

private extension String {
  static let tonSymbol = TonInfo.symbol
  static let usdtSymbol = "USD₮"
  static let jusdtSymbol = "jUSDT"
}
