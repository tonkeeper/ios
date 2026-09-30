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

    public func tonAPISSEEndpointV2(network: Network) async -> String? {
        _ = await loadConfigurations()
        return configuration(for: network).tonAPISSEEndpointV2
    }

    public func batteryHost(network: Network) async -> String {
        _ = await loadConfigurations()
        return configuration(for: network).batteryHost
    }

    public func multichainHost(network: Network) async -> URL {
        _ = await loadConfigurations()
        return configuration(for: network).multichain.domain
    }

    public func tradingHost(network: Network) async -> URL {
        _ = await loadConfigurations()
        return configuration(for: network).trading.domain
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

    public func explorers(network: Network) -> [BootConfiguration.ChainExplorer] {
        configuration(for: network).explorers
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

    private var configurations: BootConfigurations {
        get {
            lock.withLock {
                if let _configurations {
                    return _configurations
                }
                if let configuration = try? bootConfigurationService.getConfiguration() {
                    _configurations = configuration
                    return configuration
                }
                return BootConfigurations(mainnet: .empty, testnet: .empty)
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

    private var _configurations: BootConfigurations?

    private var loadTask: Task<BootConfigurations, Swift.Error>?
    private var observers = [UUID: () -> Void]()

    private let lock = NSLock()

    private let bootConfigurationService: BootConfigurationService
    private let featureFlags: TKFeatureFlags
    private let tkAppSettings: TKAppSettings

    init(
        bootConfigurationService: BootConfigurationService,
        featureFlags: TKFeatureFlags,
        tkAppSettings: TKAppSettings
    ) {
        self.bootConfigurationService = bootConfigurationService
        self.featureFlags = featureFlags
        self.tkAppSettings = tkAppSettings
    }

    public func flag(_ keyPath: KeyPath<BootConfiguration.Flags, Bool>, network: Network) -> Bool {
        configuration(for: network).flags[keyPath: keyPath]
    }

    public func value<Value>(_ keyPath: KeyPath<BootConfiguration, Value>, network: Network = .mainnet) -> Value {
        configuration(for: network)[keyPath: keyPath]
    }

    public var resolvedFeatureFlags: [FeatureFlag: Bool] {
        FeatureFlag.allCases.reduce(into: [FeatureFlag: Bool]()) { result, feature in
            result[feature] = featureEnabled(feature)
        }
    }

    public func featureEnabled(_ feature: FeatureFlag) -> Bool {
        resolveFeatureFlag(feature)
    }

    private func resolveFeatureFlag(_ feature: FeatureFlag) -> Bool {
        if let devOverride = featureFlags.devOverride(for: feature) {
            return devOverride
        }
        return featureFlags[feature]
    }

    private func configuration(for network: Network) -> BootConfiguration {
        switch network {
        case .mainnet:
            return self.configurations.mainnet
        case .testnet:
            return self.configurations.testnet
        }
    }

    public func loadConfigurations() async -> BootConfigurations {
        let task = lock.withLock {
            if let loadTask: Task<BootConfigurations, any Error> {
                return loadTask
            }
            let task = Task<BootConfigurations, Swift.Error> {
                let configuration = try await bootConfigurationService.loadConfiguration()
                self.configurations = configuration
                return configuration
            }
            self.loadTask = task
            return task
        }

        do {
            return try await task.value
        } catch {
            // Retry failures without clearing a replacement started by another caller.
            lock.withLock {
                if self.loadTask == task {
                    self.loadTask = nil
                }
            }
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
                self.lock.withLock {
                    _ = self.observers.removeValue(forKey: id)
                }
                return
            }
            closure(observer)
        }
        lock.withLock {
            self.observers[id] = observerClosure
        }
    }
}
