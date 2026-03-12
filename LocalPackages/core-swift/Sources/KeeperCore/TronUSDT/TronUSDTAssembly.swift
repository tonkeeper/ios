import Foundation
import TronSwiftAPI

public final class TronUSDTAssembly {
    private let secureAssembly: SecureAssembly
    private let storesAssembly: StoresAssembly
    private let batteryAPIAssembly: BatteryAPIAssembly
    private let configurationAssembly: ConfigurationAssembly

    init(
        secureAssembly: SecureAssembly,
        storesAssembly: StoresAssembly,
        batteryAPIAssembly: BatteryAPIAssembly,
        configurationAssembly: ConfigurationAssembly
    ) {
        self.secureAssembly = secureAssembly
        self.storesAssembly = storesAssembly
        self.batteryAPIAssembly = batteryAPIAssembly
        self.configurationAssembly = configurationAssembly
    }

    public func walletConfigurator() -> TronWalletConfigurator {
        TronWalletConfigurator(
            walletsStore: storesAssembly.walletsStore,
            mnemonicRepository: secureAssembly.mnemonicsRepository()
        )
    }

    public func balanceService() -> TronBalanceService {
        TronBalanceServiceImplementation(api: TronSwiftAPI.API(urlSession: .shared, baseApiUrl: configurationAssembly.configuration.tronApiUrl))
    }

    public var api: TronAPI {
        TronAPI(
            tronApi: TronSwiftAPI.API(urlSession: .shared, baseApiUrl: configurationAssembly.configuration.tronApiUrl),
            batteryAPI: batteryAPIAssembly.api
        )
    }
}
