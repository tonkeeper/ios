import Foundation

public actor SecurityStore {
  public typealias ObservationClosure = (Event) -> Void
  public enum Event {
    case didUpdateSecuritySettings
  }
  
  private let securityService: SecurityService
  
  init(securityService: SecurityService) {
    self.securityService = securityService
  }
  
  public var isBiometryEnabled: Bool {
    securityService.isBiometryTurnedOn
  }
  
  public func setIsBiometryEnabled(_ isBiometryEnabled: Bool) throws {
    try securityService.updateBiometry(isBiometryEnabled)
    observations.values.forEach { $0(.didUpdateSecuritySettings) }
  }
  
  private var observations = [UUID: ObservationClosure]()
  
  public func addEventObserver<T: AnyObject>(_ observer: T,
                                             closure: @escaping (T, Event) -> Void) -> ObservationToken {
    let id = UUID()
    let eventHandler: (Event) -> Void = { [weak self, weak observer] event in
      guard let self else { return }
      guard let observer else {
        Task { await self.removeObserver(id: id) }
        return
      }
      
      closure(observer, event)
    }
    observations[id] = eventHandler
    
    return ObservationToken { [weak self] in
      guard let self else { return }
      Task { await self.removeObserver(id: id) }
    }
  }
  
  func removeObserver(id: UUID) {
    observations.removeValue(forKey: id)
  }
}
