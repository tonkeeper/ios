import Foundation

public actor AssetsStore {
  private let swapService: SwapService
  
  init(swapService: SwapService) {
    self.swapService = swapService
  }

  private var _cachedAssets: [Asset]? = nil
  public func getAssets() async -> [Asset]? {
    if let _cachedAssets {
      return _cachedAssets
    }
    let assetList = try? await swapService.getAssets()
    _cachedAssets = assetList?.result.assets.filter({ asset in
      asset.blacklisted != true &&
      asset.community != true &&
      asset.deprecated != true
    })
    return _cachedAssets
  }

  private var _cachedPairs: [String: [String]]? = nil
  public func getPairs() async -> [String: [String]]? {
    if let _cachedPairs {
      return _cachedPairs
    }
    let pairs = try? await swapService.getPairs()
    var pairsDictionary = [String: [String]]()
    for pair in pairs?.result.pairs ?? [] {
      if pairsDictionary[pair[0]] == nil {
        pairsDictionary[pair[0]] = [pair[1]]
      } else {
        pairsDictionary[pair[0]]?.append(pair[1])
      }
      if pairsDictionary[pair[1]] == nil {
        pairsDictionary[pair[1]] = [pair[0]]
      } else {
        pairsDictionary[pair[1]]?.append(pair[0])
      }
    }
    _cachedPairs = pairsDictionary
    return pairsDictionary
  }
}
