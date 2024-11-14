import Foundation

public final class BatteryAssembly {
  
  private let batteryAPIAssembly: BatteryAPIAssembly
  private let coreAssembly: CoreAssembly
  
  init(batteryAPIAssembly: BatteryAPIAssembly,
       coreAssembly: CoreAssembly) {
    self.batteryAPIAssembly = batteryAPIAssembly
    self.coreAssembly = coreAssembly
  }

  public func batteryService() -> BatteryService {
    BatteryServiceImplementation(
      batteryAPIProvider: batteryAPIAssembly.apiProvider,
      rechargeMethodsRepository: rechargeMethodsRepository()
    )
  }
  
  private weak var _batteryPromocodeStore: BatteryPromocodeStore?
  public func batteryPromocodeStore() -> BatteryPromocodeStore {
    if let batteryPromocodeStore = _batteryPromocodeStore {
      return batteryPromocodeStore
    } else {
      let batteryPromocodeStore = BatteryPromocodeStore(repository: promocodeRepository())
      _batteryPromocodeStore = batteryPromocodeStore
      return batteryPromocodeStore
    }
  }
  
  public func rechargeMethodsRepository() -> BatteryRechargeMethodsRepository {
    BatteryRechargeMethodsRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
  }
  
  public func promocodeRepository() -> BatteryPromocodeRepository {
    BatteryPromocodeRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
  }
}
