import Foundation

public final class SwapTokenListController {
  
  public var didUpdateTokenListItemsModel: ((TokenListItemsModel) -> Void)?
  
  private var tokenListItems: [TokenListItemsModel.Item] = []
  
  private let stonfiAssetsStore: StonfiAssetsStore
  private let stonfiAssetsLoader: StonfiAssetsLoader
  
  init(stonfiAssetsStore: StonfiAssetsStore, stonfiAssetsLoader: StonfiAssetsLoader) {
    self.stonfiAssetsStore = stonfiAssetsStore
    self.stonfiAssetsLoader = stonfiAssetsLoader
  }
  
  public func start() async {
    _ = await stonfiAssetsStore.addEventObserver(self) { [weak self] observer, event in
      switch event {
      case .didUpdateAssets(let assets):
        self?.assetsDidUpdate(assets)
      }
    }
    
    let storedAssets = await stonfiAssetsStore.getAssets()
    let items = storedAssets.items
    let expirationDate = storedAssets.expirationDate
    
    let isStoredAssetsValid = !items.isEmpty && expirationDate.timeIntervalSinceNow > 0
    
    if isStoredAssetsValid {
      print("SwapTokenListController using stored assets")
      assetsDidUpdate(storedAssets)
    } else {
      print("SwapTokenListController loadAssets")
      await stonfiAssetsLoader.loadAssets()
    }
  }
}

private extension SwapTokenListController {
  func assetsDidUpdate(_ assets: StonfiAssets) {
    let tokenListItems = assets.items.map { asset in
      mapStonfiAsset(asset)
    }
    let tokenListItemsModel = TokenListItemsModel(items: tokenListItems)
    
    Task { @MainActor in
      self.tokenListItems = tokenListItems
      didUpdateTokenListItemsModel?(tokenListItemsModel)
    }
  }
  
  func mapStonfiAsset(_ asset: StonfiAsset) -> TokenListItemsModel.Item {
    var imageUrl: URL?
    if let imageUrlString = asset.imageUrl  {
      imageUrl = URL(string: imageUrlString)
    }
    
    return TokenListItemsModel.Item(
      identifier: asset.contractAddress,
      image: .asyncImage(imageUrl),
      symbol: asset.symbol,
      displayName: asset.displayName ?? "",
      badge: nil,
      amount: nil,
      convertedAmount: nil
    )
  }
}
