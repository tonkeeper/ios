import Foundation

public final class BatteryAssembly {
    private let batteryAPIAssembly: BatteryAPIAssembly
    private let coreAssembly: CoreAssembly
    private let configurationAssembly: ConfigurationAssembly
    private let tonProofTokenService: TonProofTokenService
    private let deviceAuth: DeviceAuthProviding
    private let walletAuthTokenProvider: WalletAuthTokenProviding

    init(
        batteryAPIAssembly: BatteryAPIAssembly,
        coreAssembly: CoreAssembly,
        configurationAssembly: ConfigurationAssembly,
        tonProofTokenService: TonProofTokenService,
        deviceAuth: DeviceAuthProviding,
        walletAuthTokenProvider: WalletAuthTokenProviding
    ) {
        self.batteryAPIAssembly = batteryAPIAssembly
        self.coreAssembly = coreAssembly
        self.configurationAssembly = configurationAssembly
        self.tonProofTokenService = tonProofTokenService
        self.deviceAuth = deviceAuth
        self.walletAuthTokenProvider = walletAuthTokenProvider
    }

    public func batteryService() -> BatteryService {
        BatteryServiceImplementation(
            batteryAPIProvider: batteryAPIAssembly.apiProvider,
            rechargeMethodsRepository: rechargeMethodsRepository(),
            authorizationService: BatteryAuthorizationService(
                tonProofTokenService: tonProofTokenService,
                deviceAuth: deviceAuth,
                walletAuthTokenProvider: walletAuthTokenProvider
            )
        )
    }

    public func batteryWebAuthorizationService() -> BatteryWebAuthorizationService {
        BatteryWebAuthorizationServiceImplementation(
            deviceAuth: deviceAuth,
            walletAuthTokenProvider: walletAuthTokenProvider
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

    public var batteryCalculation: BatteryCalculation {
        BatteryCalculation(configuration: configurationAssembly.configuration)
    }
}
