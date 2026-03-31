import Foundation

public final class TransferAssembly {
    private let servicesAssembly: ServicesAssembly
    private let batteryAssembly: BatteryAssembly
    private let configurationAssembly: ConfigurationAssembly
    private let repositoriesAssembly: RepositoriesAssembly
    private let storesAssembly: StoresAssembly

    init(
        servicesAssembly: ServicesAssembly,
        batteryAssembly: BatteryAssembly,
        configurationAssembly: ConfigurationAssembly,
        repositoriesAssembly: RepositoriesAssembly,
        storesAssembly: StoresAssembly
    ) {
        self.servicesAssembly = servicesAssembly
        self.batteryAssembly = batteryAssembly
        self.configurationAssembly = configurationAssembly
        self.repositoriesAssembly = repositoriesAssembly
        self.storesAssembly = storesAssembly
    }

    public func transferService() -> TransferService {
        TransferService(
            tonProofTokenService: servicesAssembly.tonProofTokenService(),
            batteryService: batteryAssembly.batteryService(),
            balanceService: servicesAssembly.balanceService(),
            sendService: servicesAssembly.sendService(),
            accountService: servicesAssembly.accountService(),
            configuration: configurationAssembly.configuration,
            settingsRepository: repositoriesAssembly.settingsRepository(),
            currencyStore: storesAssembly.currencyStore
        )
    }
}
