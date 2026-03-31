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
        TronBalanceServiceImplementation(api: tronApi)
    }

    public private(set) lazy var tronUsdtApi: TronUSDTAPI = TronUSDTAPI(
        tronApi: tronApi,
        batteryAPI: batteryAPIAssembly.api,
        chainParametersRepository: tronChainParametersRepository
    )

    private lazy var tronChainParametersRepository: TronChainParametersRepository =
        TronChainParametersRepositoryImplementation()

    private lazy var tronApi = TronApi(
        urlSession: .shared,
        baseApiUrl: configurationAssembly.configuration.tronApiUrl
    )
}
