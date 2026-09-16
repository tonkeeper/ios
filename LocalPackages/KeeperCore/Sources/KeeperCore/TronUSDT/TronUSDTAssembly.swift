import Foundation
import TronSwiftAPI

public final class TronUSDTAssembly {
    private let secureAssembly: SecureAssembly
    private let storesAssembly: StoresAssembly
    private let batteryAPIAssembly: BatteryAPIAssembly
    private let batteryAssembly: BatteryAssembly
    private let configurationAssembly: ConfigurationAssembly
    private let repositoriesAssembly: RepositoriesAssembly

    init(
        secureAssembly: SecureAssembly,
        storesAssembly: StoresAssembly,
        batteryAPIAssembly: BatteryAPIAssembly,
        batteryAssembly: BatteryAssembly,
        configurationAssembly: ConfigurationAssembly,
        repositoriesAssembly: RepositoriesAssembly
    ) {
        self.secureAssembly = secureAssembly
        self.storesAssembly = storesAssembly
        self.batteryAPIAssembly = batteryAPIAssembly
        self.batteryAssembly = batteryAssembly
        self.configurationAssembly = configurationAssembly
        self.repositoriesAssembly = repositoriesAssembly
    }

    public func walletMigration() -> TronWalletMigration {
        TronWalletMigrationImplementation(
            dependencies: TronWalletMigrationDependencies(
                isMigrationCompleted: { [repositoriesAssembly] in
                    repositoriesAssembly.settingsRepository().didMigrateLegacyTronWalletsV1
                },
                completeMigration: { [repositoriesAssembly] in
                    var settingsRepository = repositoriesAssembly.settingsRepository()
                    settingsRepository.didMigrateLegacyTronWalletsV1 = true
                },
                getWallets: { [storesAssembly] in
                    storesAssembly.walletsStore.wallets
                },
                getMnemonics: { [secureAssembly] wallets, passcode in
                    try await secureAssembly.mnemonicAccess.getMnemonics(
                        wallets: wallets,
                        passcode: passcode
                    )
                },
                saveWalletTron: { [storesAssembly] wallet, tron in
                    await storesAssembly.walletsStore.setWalletTron(wallet: wallet, tron: tron)
                }
            )
        )
    }

    public func balanceService() -> TronBalanceService {
        TronBalanceServiceImplementation(api: tronApi)
    }

    public private(set) lazy var tronUsdtApi: TronUSDTAPI = TronUSDTAPI(
        tronApi: tronApi,
        batteryAPI: batteryAPIAssembly.api,
        batteryService: batteryAssembly.batteryService(),
        chainParametersRepository: tronChainParametersRepository
    )

    private lazy var tronChainParametersRepository: TronChainParametersRepository =
        TronChainParametersRepositoryImplementation()

    private lazy var tronApi = TronApi(
        urlSession: Self.makeUrlSession(),
        baseApiUrl: configurationAssembly.configuration.tronApiUrl
    )

    /// A built TRON transaction expires, so a request hanging on `URLSession.shared`'s minute-long
    /// default eats into the window the signed transaction still has to reach the chain.
    private static func makeUrlSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        return URLSession(configuration: configuration)
    }
}
