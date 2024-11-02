import Foundation

public final class Configuration {
  
  public var tonapiV2Endpoint: String {
    get async {
      await loadConfiguration().tonapiV2Endpoint
    }
  }
  public var tonapiTestnetHost: String {
    get async {
      await loadConfiguration().tonapiTestnetHost
    }
  }
  public var batteryHost: String {
    get async {
      await loadConfiguration().batteryHost
    }
  }
  public var tonApiV2Key: String {
    get async {
      await loadConfiguration().tonApiV2Key
    }
  }
  public var mercuryoSecret: String? {
    get async {
      await loadConfiguration().mercuryoSecret
    }
  }
  public var accountExplorer: String? {
    get {
      configuration.accountExplorer
    }
  }
  public var accountExplorerTestnet: String? {
    get {
      configuration.accountExplorerTestnet
    }
  }
  public var transactionExplorer: String? {
    get {
      configuration.transactionExplorer
    }
  }
  public var transactionExplorerTestnet: String? {
    get {
      configuration.transactionExplorerTestnet
    }
  }
  public var nftOnExplorerUrl: String? {
    get {
      configuration.nftOnExplorerUrl
    }
  }
  public var nftOnExplorerTestnetUrl: String?  {
    get {
      configuration.nftOnExplorerTestnetUrl
    }
  }
  public var supportLink: URL?  {
    get {
      configuration.supportLink
    }
  }
  public var directSupportUrl: URL?  {
    get {
      configuration.directSupportUrl
    }
  }
  public var tonkeeperNewsUrl: URL?  {
    get {
      configuration.tonkeeperNewsUrl
    }
  }
  public var stonfiUrl: URL?  {
    get {
      configuration.stonfiUrl
    }
  }
  public var faqUrl: URL?  {
    get {
      configuration.faqUrl
    }
  }
  public var stakingInfoUrl: URL?  {
    get {
      configuration.stakingInfoUrl
    }
  }
  public var flags: RemoteConfiguration.Flags {
    get {
      configuration.flags
    }
  }
  public var batteryMeanFeesDecimaNumber: NSDecimalNumber? {
    configuration.batteryMeanFeesDecimaNumber
  }
  
  public var batteryReservedAmountDecimalNumber: NSDecimalNumber? {
    configuration.batteryReservedAmountDecimalNumber
  }
  
  public var batteryMeanFeesPriceSwapDecimaNumber: NSDecimalNumber? {
    configuration.batteryMeanFeesPriceSwapDecimaNumber
  }
  
  public var batteryMeanFeesPriceJettonDecimaNumber: NSDecimalNumber? {
    configuration.batteryMeanFeesPriceJettonDecimaNumber
  }
  
  public var batteryMeanFeesPriceNFTDecimaNumber: NSDecimalNumber? {
    configuration.batteryMeanFeesPriceNFTDecimaNumber
  }
  
  public var batteryMaxInputAmount: NSDecimalNumber {
    get async {
      await loadConfiguration().batteryMaxInputAmountDecimaNumber
    }
  }
  
  public var isBatteryEnable: Bool {
    get async {
      await !loadConfiguration().disableBattery
    }
  }
  
  public var isBatterySendEnable: Bool {
    get async {
      await !loadConfiguration().disableBatterySend
    }
  }
  
  public var isBatteryBeta: Bool {
    configuration.isBatteryBeta
  }

  private(set) public var configuration: RemoteConfiguration {
    get {
      lock.withLock {
        if let _configuration { return _configuration }
        if let configuration = try? remoteConfigurationService.getConfiguration() {
          _configuration = configuration
          return configuration
        }
        return .empty
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
  private var _configuration: RemoteConfiguration?
  
  private var loadTask: Task<RemoteConfiguration, Swift.Error>?
  private var observers = [UUID: () -> Void]()
  
  private let lock = NSLock()
  
  private let remoteConfigurationService: RemoteConfigurationService
  
  init(remoteConfigurationService: RemoteConfigurationService) {
    self.remoteConfigurationService = remoteConfigurationService
  }
  
  public func loadConfiguration() async -> RemoteConfiguration {
    let task = lock.withLock {
      if let loadTask {
        return loadTask
      }
      let task = Task<RemoteConfiguration, Swift.Error> {
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
