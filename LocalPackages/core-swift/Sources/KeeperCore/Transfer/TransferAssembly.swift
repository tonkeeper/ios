import Foundation

public final class TransferAssembly {
  private let servicesAssembly: ServicesAssembly
  private let batteryAssembly: BatteryAssembly
  private let configurationAssembly: ConfigurationAssembly
  
  init(servicesAssembly: ServicesAssembly,
       batteryAssembly: BatteryAssembly,
       configurationAssembly: ConfigurationAssembly) {
    self.servicesAssembly = servicesAssembly
    self.batteryAssembly = batteryAssembly
    self.configurationAssembly = configurationAssembly
  }
  
  public func transferService() -> TransferService {
    TransferService(
      tonProofTokenService: servicesAssembly.tonProofTokenService(),
      batteryService: batteryAssembly.batteryService(),
      balanceService: servicesAssembly.balanceService(),
      sendService: servicesAssembly.sendService(),
      accountService: servicesAssembly.accountService(),
      configuration: configurationAssembly.configuration
    )
  }
}
