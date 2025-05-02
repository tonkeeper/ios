import Foundation
import TronSwiftAPI

public final class TronUSDTAssembly {
  
  private let secureAssembly: SecureAssembly
  private let storesAssembly: StoresAssembly
  private let batteryAPIAssembly: BatteryAPIAssembly
  
  init(secureAssembly: SecureAssembly,
       storesAssembly: StoresAssembly,
       batteryAPIAssembly: BatteryAPIAssembly) {
    self.secureAssembly = secureAssembly
    self.storesAssembly = storesAssembly
    self.batteryAPIAssembly = batteryAPIAssembly
  }
  
  public func walletConfigurator() -> TronWalletConfigurator {
    TronWalletConfigurator(
      walletsStore: storesAssembly.walletsStore,
      mnemonicRepository: secureAssembly.mnemonicsRepository()
    )
  }
  
  public func balanceService() -> TronBalanceService {
    TronBalanceServiceImplementation(api: TronSwiftAPI.API(urlSession: .shared))
  }
  
  public var api: TronAPI {
    TronAPI(tronApi: TronSwiftAPI.API(urlSession: .shared),
            batteryAPI: batteryAPIAssembly.api)
  }
}
