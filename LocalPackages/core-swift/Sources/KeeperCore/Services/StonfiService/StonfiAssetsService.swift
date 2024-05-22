import Foundation
import TonSwift

protocol StonfiAssetsService {
  func getAssets() async throws -> StonfiAssets
  func loadAssets() async throws -> StonfiAssets
  func loadAssetsInfo(addresses: [Address]) async throws -> [StonfiAsset]
}

final class StonfiAssetsServiceImplementation: StonfiAssetsService {
  private let stonfiApi: StonfiAPI
  private let stonfiAssetsRepository: StonfiAssetsRepository
  
  init(stonfiApi: StonfiAPI, stonfiAssetsRepository: StonfiAssetsRepository) {
    self.stonfiApi = stonfiApi
    self.stonfiAssetsRepository = stonfiAssetsRepository
  }
  
  func getAssets() throws -> StonfiAssets {
    return try stonfiAssetsRepository.getAssets()
  }
  
  func loadAssets() async throws -> StonfiAssets {
    let items = try await stonfiApi.getStonfiAssets()
      .filter { isValidStonfiAsset($0) }
      .sorted { $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending }
    
    let assets = StonfiAssets(
      expirationDate: Date().advanced(by: .hours(1)),
      items: items
    )
    
    try? stonfiAssetsRepository.saveAssets(assets)
    
    return assets
  }
  
  func loadAssetsInfo(addresses: [Address]) async throws -> [StonfiAsset] {
    return try await stonfiApi.getAssetsInfo(addresses: addresses)
  }
}

private extension StonfiAssetsServiceImplementation {
  func isValidStonfiAsset(_ asset: StonfiAsset) -> Bool {
    return asset.kind.uppercased() != "WTON"
    && !asset.isCommunity
    && !asset.isDeprecated
    && !asset.isBlacklisted
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
