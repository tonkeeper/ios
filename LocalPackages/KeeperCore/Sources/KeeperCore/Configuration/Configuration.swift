import Foundation
import PerpsModels
import TKFeatureFlags

public final class Configuration {
    var cachedTonAPIConnection: (url: URL, key: String)? {
        guard let config = availableConfigurations?.mainnet,
              let url = URL(string: config.tonapiV2Endpoint), url.host != nil
        else { return nil }
        return (url, config.tonApiV2Key)
    }

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

    /// A cold start takes the host from the last launch's configuration instead of waiting a round trip
    /// for the load; the load still runs, and its answer serves the requests after it.
    public func multichainHost(network: Network) async -> URL {
        if !lock.withLock({ isLoaded }), availableConfigurations != nil {
            Task { _ = await loadConfigurations() }
        } else {
            _ = await loadConfigurations()
        }
        return configuration(for: network).multichain.domain
    }

    public func tradingHost(network: Network) async -> URL {
        _ = await loadConfigurations()
        return configuration(for: network).trading.domain
    }

    public func keeperEarnHost(network: Network) async -> URL {
        _ = await loadConfigurations()
        return configuration(for: network).keeperEarn
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

    public var earnUrl: URL {
        configurations.mainnet.earnUrl
    }

    public var earnFeaturedVaults: [EarnFeaturedVault] {
        configurations.mainnet.earnFeaturedVaults
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
        return !overridableFlag(\.disableBattery, key: .disableBattery, network: network)
    }

    public func isBatterySendEnable(network: Network) async -> Bool {
        _ = await loadConfigurations()
        return !overridableFlag(\.disableBatterySend, key: .disableBatterySend, network: network)
    }

    public func reportAmount(network: Network) -> NSDecimalNumber {
        configuration(for: network).reportAmountDecimalNumber
    }

    public func isBatteryBeta(network: Network) -> Bool {
        configuration(for: network).isBatteryBeta
    }

    var perpsAccess: PerpsAccess {
        perpsAccessOverride ?? value(\.perpsAccess)
    }

    public func isTRXOnlyRegion(network: Network) -> Bool {
        configuration(for: network).flags.trxOnlyRegion
    }

    public func isDisableBatteryCryptoRechargeModule(network: Network) -> Bool {
        overridableFlag(\.disableBatteryCryptoRechargeModule, key: .disableBatteryCryptoRechargeModule, network: network)
    }

    public func isDisableBatteryPromoModule(network: Network) -> Bool {
        overridableFlag(\.disableBatteryPromoModule, key: .disableBatteryPromoModule, network: network)
    }

    /// The bundled FlagsOverride.json (dev/CI builds only) wins over keys/all for a
    /// top-level Bool of the configuration, the same way it does for the nested `flags`;
    /// the override is applied when the value is read, so the parsed configuration
    /// stays what the backend sent.
    private func overridableFlag(
        _ keyPath: KeyPath<BootConfiguration, Bool>,
        key: BootConfiguration.CodingKeys,
        network: Network
    ) -> Bool {
        if let override = StaticFlagOverrides.shared?.bootConfigurationFlags?[key.rawValue] {
            return override
        }
        return configuration(for: network)[keyPath: keyPath]
    }

    /// The loaded configuration, else the one an earlier launch stored; nil when there is neither.
    private var availableConfigurations: BootConfigurations? {
        lock.withLock {
            if _configurations == nil {
                _configurations = try? bootConfigurationService.getConfiguration()
            }
            return _configurations
        }
    }

    private var configurations: BootConfigurations {
        get {
            availableConfigurations ?? BootConfigurations(mainnet: .empty, testnet: .empty)
        }
        set {
            var observers = [UUID: () -> Void]()
            let changed = lock.withLock {
                let changed = !isLoaded || _configurations != newValue
                observers = self.observers
                _configurations = newValue
                isLoaded = true
                return changed
            }
            guard changed else { return }
            observers.forEach { $0.value() }
        }
    }

    private var _configurations: BootConfigurations?
    private var isLoaded = false

    private var loadTask: Task<BootConfigurations, Swift.Error>?
    private var isLoadInFlight = false
    private var observers = [UUID: () -> Void]()

    private let lock = NSLock()

    private let bootConfigurationService: BootConfigurationService
    private let featureFlags: TKFeatureFlags
    private let tkAppSettings: TKAppSettings
    private let perpsAccessOverride: PerpsAccess?

    init(
        bootConfigurationService: BootConfigurationService,
        featureFlags: TKFeatureFlags,
        tkAppSettings: TKAppSettings,
        perpsAccessOverride: PerpsAccess? = nil
    ) {
        self.bootConfigurationService = bootConfigurationService
        self.featureFlags = featureFlags
        self.tkAppSettings = tkAppSettings
        self.perpsAccessOverride = perpsAccessOverride
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

    public var featureFlagsDescription: String {
        let values = featureFlags.allValues
        let features = FeatureFlag.allCases.sorted { $0.localKey < $1.localKey }
        let nameWidth = features.map(\.localKey.count).max() ?? 0
        let valueWidth = "false".count
        return features
            .map { feature in
                let name = feature.localKey.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
                let enabled = "\(featureEnabled(feature))"
                guard let source = values[feature]?.source else {
                    return "  \(name)  \(enabled)"
                }
                return "  \(name)  \(enabled.padding(toLength: valueWidth, withPad: " ", startingAt: 0))  \(source)"
            }
            .joined(separator: "\n")
    }

    public func featureEnabled(_ feature: FeatureFlag) -> Bool {
        resolveFeatureFlag(feature)
    }

    /// The battery's relayer pays fees on Solana only while `solanaGaslessEnabled` is on.
    public func relaysGasless(on chain: MultichainChain) -> Bool {
        chain != .sol || featureEnabled(.solanaGaslessEnabled)
    }

    /// The Perps banner and story share the id `perps` and stay hidden while Perps is off.
    public func isPromoHidden(id: String) -> Bool {
        id == "perps" && !featureEnabled(.perpsEnabled)
    }

    private func resolveFeatureFlag(_ feature: FeatureFlag) -> Bool {
        if let requirement = feature.requirement, !resolveFeatureFlag(requirement) {
            return false
        }
        if let devOverride = featureFlags.devOverride(for: feature) {
            return devOverride
        }
        if isFeatureFlagDisabledByBootConfiguration(feature) {
            return false
        }
        return featureFlags[feature]
    }

    private func isFeatureFlagDisabledByBootConfiguration(_ feature: FeatureFlag) -> Bool {
        switch feature {
        case .perpsEnabled:
            perpsAccess == .hidden
        default:
            false
        }
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
        await loadConfigurations(replacingLoaded: false)
    }

    public func reloadConfigurations() async -> BootConfigurations {
        await loadConfigurations(replacingLoaded: true)
    }

    private func loadConfigurations(replacingLoaded: Bool) async -> BootConfigurations {
        let task: Task<BootConfigurations, Swift.Error>? = lock.withLock {
            if !replacingLoaded, isLoaded {
                return nil
            }
            if let loadTask: Task<BootConfigurations, any Error>, isLoadInFlight || !replacingLoaded {
                return loadTask
            }
            isLoadInFlight = true
            let task = Task<BootConfigurations, Swift.Error> {
                defer { self.lock.withLock { self.isLoadInFlight = false } }
                let configuration = try await bootConfigurationService.loadConfiguration()
                self.configurations = configuration
                return configuration
            }
            self.loadTask = task
            return task
        }
        guard let task else { return configurations }

        do {
            return try await task.value
        } catch {
            // Retry failures without clearing a replacement started by another caller.
            lock.withLock {
                if self.loadTask == task, !self.isLoaded {
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
