import Foundation
import TKFeatureFlags

public final class Configuration {
    public var tonapiV2Endpoint: String {
        get async {
            await loadConfigurations().mainnet.tonapiV2Endpoint
        }
    }

    public var tonConnectBridge: String {
        get async {
            await loadConfigurations().mainnet.tonConnectBridge
        }
    }

    public var tonapiTestnetHost: String {
        get async {
            await loadConfigurations().testnet.tonapiV2Endpoint
        }
    }

    public var tetraHost: String {
        get async {
            await loadConfigurations().tetra.tonapiV2Endpoint
        }
    }

    public func tonAPISSEEndpoint(network: Network) async -> String {
        _ = await loadConfigurations()
        return configuration(for: network).tonAPISSEEndpoint
    }

    public func batteryHost(network: Network) async -> String {
        _ = await loadConfigurations()
        return configuration(for: network).batteryHost
    }

    public var testnetBatteryHost: String {
        get async {
            await loadConfigurations().mainnet.batteryHost
        }
    }

    public var tonApiV2Key: String {
        get async {
            await loadConfigurations().mainnet.tonApiV2Key
        }
    }

    public var stories: [String] {
        get async {
            await loadConfigurations().mainnet.stories ?? []
        }
    }

    public func scamApiURL(network: Network) async -> URL? {
        _ = await loadConfigurations()
        return configuration(for: network).scamApiURL
    }

    public var mercuryoSecret: String? {
        get async {
            await loadConfigurations().mainnet.mercuryoSecret
        }
    }

    public var supportLink: URL? {
        configurations.mainnet.supportLink
    }

    public var directSupportUrl: URL? {
        configurations.mainnet.directSupportUrl
    }

    public var tonkeeperNewsUrl: URL? {
        configurations.mainnet.tonkeeperNewsUrl
    }

    public var stonfiUrl: URL? {
        configurations.mainnet.stonfiUrl
    }

    public var faqUrl: URL? {
        configurations.mainnet.faqUrl
    }

    public var stakingInfoUrl: URL? {
        configurations.mainnet.stakingInfoUrl
    }

    public var isConfirmButtonInsteadSlider: Bool {
        tkAppSettings.isConfirmButtonInsteadSlider
    }

    public var isTetraWalletEnabled: Bool {
        tkAppSettings.isTetraWalletEnabled
    }

    public var multichainHelpUrl: URL? {
        configurations.mainnet.multichainHelpUrl
    }

    public var tronApiUrl: URL {
        if let url = configurations.mainnet.tronApiUrl, let result = URL(string: url) {
            return result
        }

        return URL(string: "https://api.trongrid.io/")!
    }

    public func accountExplorer(network: Network) -> String? {
        configuration(for: network).accountExplorer
    }

    public func nftOnExplorer(network: Network) -> String? {
        configuration(for: network).nftOnExplorerUrl
    }

    public func transactionExplorer(network: Network) -> String? {
        configuration(for: network).transactionExplorer
    }

    public func batteryMeanFeesDecimaNumber(network: Network) -> NSDecimalNumber? {
        configuration(for: network).batteryMeanFeesDecimaNumber
    }

    public func batteryReservedAmountDecimalNumber(network: Network) -> NSDecimalNumber? {
        configuration(for: network).batteryReservedAmountDecimalNumber
    }

    public func batteryMeanFeesPriceSwapDecimaNumber(network: Network) -> NSDecimalNumber? {
        configuration(for: network).batteryMeanFeesPriceSwapDecimaNumber
    }

    public func batteryMeanFeesPriceJettonDecimaNumber(network: Network) -> NSDecimalNumber? {
        configuration(for: network).batteryMeanFeesPriceJettonDecimaNumber
    }

    public func batteryMeanFeesPriceNFTDecimaNumber(network: Network) -> NSDecimalNumber? {
        configuration(for: network).batteryMeanFeesPriceNFTDecimaNumber
    }

    public func batteryMeanFeesPriceTRCMin(network: Network) -> NSDecimalNumber? {
        configuration(for: network).batteryMeanPriceTRCMinDecimalNumber
    }

    public func batteryMeanFeesPriceTRCMax(network: Network) -> NSDecimalNumber? {
        configuration(for: network).batteryMeanPriceTRCMaxDecimalNumber
    }

    public func batteryRefundEndpoint(network: Network) -> URL? {
        configuration(for: network).batteryRefundEndpoint
    }

    public func batteryMaxInputAmount(network: Network) async -> NSDecimalNumber {
        _ = await loadConfigurations()
        return configuration(for: network).batteryMaxInputAmountDecimaNumber
    }

    public func isBatteryEnable(network: Network) async -> Bool {
        _ = await loadConfigurations()
        return !configuration(for: network).disableBattery
    }

    public func isBatterySendEnable(network: Network) async -> Bool {
        _ = await loadConfigurations()
        return !configuration(for: network).disableBatterySend
    }

    public func reportAmount(network: Network) -> NSDecimalNumber {
        configuration(for: network).reportAmountDecimalNumber
    }

    public func isBatteryBeta(network: Network) -> Bool {
        configuration(for: network).isBatteryBeta
    }

    public func isTRXOnlyRegion(network: Network) -> Bool {
        configuration(for: network).flags.trxOnlyRegion
    }

    public func isDisableBatteryCryptoRechargeModule(network: Network) -> Bool {
        configuration(for: network).disableBatteryCryptoRechargeModule
    }

    private var configurations: RemoteConfigurations {
        get {
            lock.withLock {
                if let _configurations { return _configurations }
                if let configuration = try? remoteConfigurationService.getConfiguration() {
                    _configurations = configuration
                    return configuration
                }
                return RemoteConfigurations(mainnet: .empty, testnet: .empty, tetra: .empty)
            }
        }
        set {
            var observers = [UUID: () -> Void]()
            lock.withLock {
                observers = self.observers
                _configurations = newValue
            }
            observers.forEach { $0.value() }
        }
    }

    private var _configurations: RemoteConfigurations?

    private var loadTask: Task<RemoteConfigurations, Swift.Error>?
    private var observers = [UUID: () -> Void]()

    private let lock = NSLock()

    private let remoteConfigurationService: RemoteConfigurationService
    private let featureFlags: TKFeatureFlags
    private let tkAppSettings: TKAppSettings

    init(
        remoteConfigurationService: RemoteConfigurationService,
        featureFlags: TKFeatureFlags,
        tkAppSettings: TKAppSettings
    ) {
        self.remoteConfigurationService = remoteConfigurationService
        self.featureFlags = featureFlags
        self.tkAppSettings = tkAppSettings
    }

    public func flag(_ keyPath: KeyPath<RemoteConfiguration.Flags, Bool>, network: Network) -> Bool {
        configuration(for: network).flags[keyPath: keyPath]
    }

    public func value<Value>(_ keyPath: KeyPath<RemoteConfiguration, Value>, network: Network = .mainnet) -> Value {
        configuration(for: network)[keyPath: keyPath]
    }

    public func featureEnabled(_ feature: FeatureFlag) -> Bool {
        if isFeatureFlagDisabledByRemoteConfig(feature) {
            return false
        }
        return featureFlags[feature]
    }

    public func isFeatureFlagDisabledByRemoteConfig(_ feature: FeatureFlag) -> Bool {
        switch feature {
        case .walletKitEnabled:
            configurations.mainnet.flags.walletKitDisabled
        case .newRampFlow:
            false
        }
    }

    private func configuration(for network: Network) -> RemoteConfiguration {
        switch network {
        case .mainnet:
            return self.configurations.mainnet
        case .testnet:
            return self.configurations.testnet
        case .tetra:
            return self.configurations.tetra
        }
    }

    public func loadConfigurations() async -> RemoteConfigurations {
        let task = lock.withLock {
            if let loadTask: Task<RemoteConfigurations, any Error> {
                return loadTask
            }
            let task = Task<RemoteConfigurations, Swift.Error> {
                let configuration = try await remoteConfigurationService.loadConfiguration()
                self.configurations = configuration
                return configuration
            }
            self.loadTask = task
            return task
        }

        do {
            return try await task.value
        } catch {
            return self.configurations
        }
    }

    public func addUpdateObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T) -> Void
    ) {
        let id = UUID()
        let observerClosure: () -> Void = { [weak self, weak observer] in
            guard let self else { return }
            guard let observer else {
                self.observers.removeValue(forKey: id)
                return
            }
            closure(observer)
        }
        lock.withLock {
            self.observers[id] = observerClosure
        }
    }
}
