import Foundation

public final class Configuration {
  
  public var tonapiV2Endpoint: String {
    get async {
      await loadConfiguration().mainnet.tonapiV2Endpoint
    }
  }
  public var tonapiTestnetHost: String {
    get async {
      await loadConfiguration().testnet.tonapiV2Endpoint
    }
  }
  public func tonAPISSEEndpoint(isTestnet: Bool) async -> String {
    isTestnet
    ? await loadConfiguration().testnet.tonAPISSEEndpoint
    : await loadConfiguration().mainnet.tonAPISSEEndpoint
  }
  public func batteryHost(isTestnet: Bool) async -> String {
    isTestnet
    ? await loadConfiguration().testnet.batteryHost
    : await loadConfiguration().mainnet.batteryHost
  }
  public var testnetBatteryHost: String {
    get async {
      await loadConfiguration().mainnet.batteryHost
    }
  }
  public var tonApiV2Key: String {
    get async {
      await loadConfiguration().mainnet.tonApiV2Key
    }
  }
  public func scamApiURL(isTestnet: Bool) async -> URL? {
    isTestnet
    ? await loadConfiguration().testnet.scamApiURL
    : await loadConfiguration().mainnet.scamApiURL
  }
  public var mercuryoSecret: String? {
    get async {
      await loadConfiguration().mainnet.mercuryoSecret
    }
  }
  public var accountExplorer: String? {
    get {
      configuration.mainnet.accountExplorer
    }
  }
  public var accountExplorerTestnet: String? {
    get {
      configuration.testnet.accountExplorer
    }
  }
  public var transactionExplorer: String? {
    get {
      configuration.mainnet.transactionExplorer
    }
  }
  public var transactionExplorerTestnet: String? {
    get {
      configuration.testnet.transactionExplorer
    }
  }
  public var nftOnExplorerUrl: String? {
    get {
      configuration.mainnet.nftOnExplorerUrl
    }
  }
  public var nftOnExplorerTestnetUrl: String?  {
    get {
      configuration.testnet.nftOnExplorerUrl
    }
  }
  public var supportLink: URL?  {
    get {
      configuration.mainnet.supportLink
    }
  }
  public var directSupportUrl: URL?  {
    get {
      configuration.mainnet.directSupportUrl
    }
  }
  public var tonkeeperNewsUrl: URL?  {
    get {
      configuration.mainnet.tonkeeperNewsUrl
    }
  }
  public var stonfiUrl: URL?  {
    get {
      configuration.mainnet.stonfiUrl
    }
  }
  public var faqUrl: URL?  {
    get {
      configuration.mainnet.faqUrl
    }
  }
  public var stakingInfoUrl: URL?  {
    get {
      configuration.mainnet.stakingInfoUrl
    }
  }
  public func batteryMeanFeesDecimaNumber(isTestnet: Bool) -> NSDecimalNumber? {
    isTestnet 
    ? configuration.testnet.batteryMeanFeesDecimaNumber
    : configuration.mainnet.batteryMeanFeesDecimaNumber
  }
  
  public func batteryReservedAmountDecimalNumber(isTestnet: Bool) -> NSDecimalNumber? {
    isTestnet
    ? configuration.testnet.batteryReservedAmountDecimalNumber
    : configuration.mainnet.batteryReservedAmountDecimalNumber
  }
  
  public func batteryMeanFeesPriceSwapDecimaNumber(isTestnet: Bool) -> NSDecimalNumber? {
    isTestnet
    ? configuration.testnet.batteryMeanFeesPriceSwapDecimaNumber
    : configuration.mainnet.batteryMeanFeesPriceSwapDecimaNumber
  }
  
  public func batteryMeanFeesPriceJettonDecimaNumber(isTestnet: Bool) -> NSDecimalNumber? {
    isTestnet
    ? configuration.testnet.batteryMeanFeesPriceJettonDecimaNumber
    : configuration.mainnet.batteryMeanFeesPriceJettonDecimaNumber
  }
  
  public func batteryMeanFeesPriceNFTDecimaNumber(isTestnet: Bool) -> NSDecimalNumber? {
    isTestnet
    ? configuration.testnet.batteryMeanFeesPriceNFTDecimaNumber
    : configuration.mainnet.batteryMeanFeesPriceNFTDecimaNumber
  }
  
  public func batteryRefundEndpoint(isTestnet: Bool) -> URL? {
    isTestnet ? configuration.testnet.batteryRefundEndpoint : configuration.mainnet.batteryRefundEndpoint
  }
  
  public func batteryMaxInputAmount(isTestnet: Bool) async -> NSDecimalNumber {
    await isTestnet
    ? loadConfiguration().testnet.batteryMaxInputAmountDecimaNumber
    : loadConfiguration().mainnet.batteryMaxInputAmountDecimaNumber
  }
  
  public func isBatteryEnable(isTestnet: Bool) async -> Bool {
    await isTestnet
    ? !loadConfiguration().testnet.disableBattery
    : !loadConfiguration().mainnet.disableBattery
  }
  
  public func isBatterySendEnable(isTestnet: Bool) async -> Bool {
    await isTestnet
    ? !loadConfiguration().testnet.disableBatterySend
    : !loadConfiguration().mainnet.disableBatterySend
  }
  
  public func isBatteryBeta(isTestnet: Bool) -> Bool {
    isTestnet ? configuration.testnet.isBatteryBeta : configuration.mainnet.isBatteryBeta
  }
  
  public func isDisableBatteryCryptoRechargeModule(isTestnet: Bool) -> Bool {
    isTestnet ? configuration.testnet.disableBatteryCryptoRechargeModule : configuration.mainnet.disableBatteryCryptoRechargeModule
  }

  public func flags(isTestnet: Bool) -> RemoteConfiguration.Flags {
    isTestnet ? configuration.testnet.flags : configuration.mainnet.flags
  }

  private(set) public var configuration: RemoteConfigurations {
    get {
      lock.withLock {
        if let _configuration { return _configuration }
        if let configuration = try? remoteConfigurationService.getConfiguration() {
          _configuration = configuration
          return configuration
        }
        return RemoteConfigurations(mainnet: .empty, testnet: .empty)
      }
    }
    set {
      var observers = [UUID: () -> Void]()
      lock.withLock {
        observers = self.observers
        _configuration = newValue
      }
      observers.forEach { $0.value() }
    }
  }
  private var _configuration: RemoteConfigurations?

  private var loadTask: Task<RemoteConfigurations, Swift.Error>?
  private var observers = [UUID: () -> Void]()
  
  private let lock = NSLock()
  
  private let remoteConfigurationService: RemoteConfigurationService
  
  init(remoteConfigurationService: RemoteConfigurationService) {
    self.remoteConfigurationService = remoteConfigurationService
  }
  
  public func loadConfiguration() async -> RemoteConfigurations {
    let task = lock.withLock {
      if let loadTask {
        return loadTask
      }
      let task = Task<RemoteConfigurations, Swift.Error> {
        let configuration = try await remoteConfigurationService.loadConfiguration()
        self.configuration = configuration
        return configuration
      }
      self.loadTask = task
      return task
    }
    
    do {
      let configuration = try await task.value
      return configuration
    } catch {
      return self.configuration
    }
  }
  
  public func addUpdateObserver<T: AnyObject>(_ observer: T,
                                              closure: @escaping (T) -> Void) {
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
