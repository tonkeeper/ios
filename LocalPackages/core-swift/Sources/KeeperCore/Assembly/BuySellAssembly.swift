import Foundation

public final class BuySellAssembly {
  
  private let tonkeeperApiAssembly: TonkeeperAPIAssembly
  private let coreAssembly: CoreAssembly
  
  init(tonkeeperApiAssembly: TonkeeperAPIAssembly,
       coreAssembly: CoreAssembly) {
    self.tonkeeperApiAssembly = tonkeeperApiAssembly
    self.coreAssembly = coreAssembly
  }

  private weak var _buySellProvider: BuySellProvider?
  public var buySellProvider: BuySellProvider {
    if let buySellProvider = _buySellProvider {
      return buySellProvider
    } else {
      let buySellProvider = BuySellProvider(buySellMethodsService: buySellMethodsService())
      _buySellProvider = buySellProvider
      return buySellProvider
    }
  }
  
  public func buySellMethodsService() -> BuySellMethodsService {
    BuySellMethodsServiceImplementation(
      api: tonkeeperApiAssembly.api,
      buySellMethodsRepository: buySellMethodsRepository()
    )
  }
  
  func buySellMethodsRepository() -> BuySellMethodsRepository {
    BuySellMethodsRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
  }
}
