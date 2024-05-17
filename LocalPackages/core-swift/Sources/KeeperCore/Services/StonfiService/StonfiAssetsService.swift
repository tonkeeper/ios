import Foundation

protocol StonfiAssetsService {
  func getAssets() async throws -> StonfiAssets
  func loadAssets(excludeCommunityAssets: Bool) async throws -> StonfiAssets
}

final class StonfiServiceImplementation: StonfiAssetsService {
  private let api: API
  private let stonfiAssetsRepository: StonfiAssetsRepository
  
  init(api: API, stonfiAssetsRepository: StonfiAssetsRepository) {
    self.api = api
    self.stonfiAssetsRepository = stonfiAssetsRepository
  }
  
  func getAssets() throws -> StonfiAssets {
    let assets = try stonfiAssetsRepository.getAssets()
    return assets
  }
  
  func loadAssets(excludeCommunityAssets: Bool) async throws -> StonfiAssets {
    var items = try await api.getStonfiAssets()
    
    if excludeCommunityAssets {
      items = items.lazy.filter { !$0.isCommunity }
    }
    
    items = items
      .sorted { $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending }
    
    let assets = StonfiAssets(
      expirationDate: Date().advanced(by: .hours(1)),
      items: items
    )
    
    try? stonfiAssetsRepository.saveAssets(assets)
    
    return assets
  }
}

private extension TimeInterval {
  static func seconds(_ value: Int) -> TimeInterval {
    return TimeInterval(value)
  }
  
  static func minutes(_ value: Int) -> TimeInterval {
    return .seconds(60) * TimeInterval(value)
  }
  
  static func hours(_ value: Int) -> TimeInterval {
    return .minutes(60) * TimeInterval(value)
  }
  
  static func days(_ value: Int) -> TimeInterval {
    return .hours(24) * TimeInterval(value)
  }
}
