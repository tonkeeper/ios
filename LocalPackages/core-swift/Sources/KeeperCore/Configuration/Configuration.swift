import Foundation

public final class Configuration {
  
  public var tonapiV2Endpoint: String {
    get async {
      await loadConfiguration().mainnet.tonapiV2Endpoint
    }
  }
  public var tonapiTestnetHost: String {
    get async {
      await loadConfiguration().testnet.tonapiTestnetHost
    }
  }
  public var tonApiV2Key: String {
    get async {
      await loadConfiguration().mainnet.tonApiV2Key
    }
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
