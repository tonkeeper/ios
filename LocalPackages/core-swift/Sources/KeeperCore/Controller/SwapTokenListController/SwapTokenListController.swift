import Foundation
import BigInt

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
}

struct AssetBalance {
  let assetSymbol: String
  let amount: String
  let convertedAmount: String?
}

public final class SwapTokenListController {
  
  public var didUpdateListItems: ((TokenButtonListItemsModel, TokenListItemsModel) -> Void)?
  public var didUpdateSearchResultsItems: ((TokenListItemsModel) -> Void)?
  
  private var tokenListItems: [TokenListItemsModel.Item] = []
  
  private let wallet: Wallet
  private var tonContractAddress = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
  
  private let stonfiAssetsStore: StonfiAssetsStore
  private let stonfiPairsStore: StonfiPairsStore
  private let ratesStore: RatesStore
  private let currencyStore: CurrencyStore
  private let walletsStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let stonfiAssetsLoader: StonfiAssetsLoader
  private let stonfiPairsLoader: StonfiPairsLoader
  private let stonfiPairsService: StonfiPairsService
  private let swapTokenListMapper: SwapTokenListMapper

  init(stonfiAssetsStore: StonfiAssetsStore,
       stonfiPairsStore: StonfiPairsStore,
       ratesStore: RatesStore,
       currencyStore: CurrencyStore,
       walletsStore: WalletsStore,
       walletBalanceStore: WalletBalanceStore,
       stonfiAssetsLoader: StonfiAssetsLoader,
       stonfiPairsLoader: StonfiPairsLoader,
       stonfiPairsService: StonfiPairsService,
       swapTokenListMapper: SwapTokenListMapper) {
    self.stonfiAssetsStore = stonfiAssetsStore
    self.stonfiPairsStore = stonfiPairsStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.walletsStore = walletsStore
    self.walletBalanceStore = walletBalanceStore
    self.stonfiAssetsLoader = stonfiAssetsLoader
    self.stonfiPairsLoader = stonfiPairsLoader
    self.stonfiPairsService = stonfiPairsService
    self.swapTokenListMapper = swapTokenListMapper
    self.wallet = walletsStore.activeWallet
  }
  
  public func start() async {
    _ = await stonfiAssetsStore.addEventObserver(self) { [weak self] observer, event in
      guard let self else { return }
      switch event {
      case .didUpdateAssets(let assets):
        Task { await self.assetsDidUpdate(assets) }
      }
    }
    
    await updateListItems()
  }
  
  public func updateListItems(forceUpdate: Bool = false) async {
    let storedAssets = await stonfiAssetsStore.getAssets()
    let items = storedAssets.items
    let expirationDate = storedAssets.expirationDate
    
    let isStoredAssetsValid = !items.isEmpty && expirationDate.timeIntervalSinceNow > 0
    
    if isStoredAssetsValid && !forceUpdate {
      await assetsDidUpdate(storedAssets)
    } else {
      await stonfiAssetsLoader.loadAssets(excludeCommunityAssets: false)
    }
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
      
      let tokenListItemsModel = TokenListItemsModel(items: searchResults)
      
      await MainActor.run {
        didUpdateSearchResultsItems?(tokenListItemsModel)
      }
    }
  }
}

private extension SwapTokenListController {
  func assetsDidUpdate(_ assets: StonfiAssets) async {
    let pairs = await getStonfiPairs()
    let assetsBalanceDict = await getAssetsBalanceDict()
    
    let tokenListItems: [TokenListItemsModel.Item] = assets.items
      .filter { pairs.hasPair(keyOne: $0.contractAddress, keyTwo: tonContractAddress) }
      .map { stonfiAsset in
        var tokenListItem = swapTokenListMapper.mapStonfiAsset(stonfiAsset)
        let assetBalanceList = assetsBalanceDict[tokenListItem.kind]
        let assetBalance = assetBalanceList?.first(where: { $0.assetSymbol == tokenListItem.symbol })
        tokenListItem.amount = assetBalance?.amount
        tokenListItem.convertedAmount = assetBalance?.convertedAmount
        return tokenListItem
      }
      .sorted(by: { $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending })
      .tokenListSorted()
    
    let suggestedTokenListItemsModel = createSuggestedTokenListModel(from: tokenListItems)
    let otherTokenListItemsModel = TokenListItemsModel(items: tokenListItems)
    
    await MainActor.run {
      self.tokenListItems = tokenListItems
      didUpdateListItems?(suggestedTokenListItemsModel, otherTokenListItemsModel)
    }
  }
  
  func createSuggestedTokenListModel(from tokenListItems: [TokenListItemsModel.Item]) -> TokenButtonListItemsModel {
    let items = tokenListItems
      .filter { suggestedTokenSymbols.contains($0.symbol) }
      .map { swapTokenListMapper.mapTokenListItem($0) }
    
    return TokenButtonListItemsModel(items: items)
  }
  
  func getAssetsBalanceDict() async -> [AssetKind : [AssetBalance]] {
    let walletBalanceState = try? await walletBalanceStore.getBalanceState(walletAddress: wallet.address)
    
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
  
  func getStonfiPairs() async -> StonfiPairs {
    let storedPairs = await stonfiPairsStore.getPairs()

    let isStoredPairsValid = !storedPairs.pairsSet.isEmpty && storedPairs.expirationDate.timeIntervalSinceNow > 0
    if isStoredPairsValid {
      return storedPairs
    } else {
      return await loadStonfiPairs()
    }
  }
  
  func loadStonfiPairs() async -> StonfiPairs {
    do {
      return try await stonfiPairsService.loadPairs()
    } catch {
      return StonfiPairs()
    }
  }
  
  var suggestedTokenSymbols: [String] {
    ["USD₮", "ANON", "GLINT", "NOT", "STON"]
  }
}

private extension Array where Element == TokenListItemsModel.Item {
  func tokenListSorted() -> [TokenListItemsModel.Item] {
    return self.sorted { (leftItem: TokenListItemsModel.Item, rightItem: TokenListItemsModel.Item) -> Bool in
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
