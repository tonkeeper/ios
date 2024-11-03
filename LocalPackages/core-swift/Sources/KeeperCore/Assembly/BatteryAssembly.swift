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
  
  public func rechargeMethodsRepository() -> BatteryRechargeMethodsRepository {
    BatteryRechargeMethodsRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
  }
}
