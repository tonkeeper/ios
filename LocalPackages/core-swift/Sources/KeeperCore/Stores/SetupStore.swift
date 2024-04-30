import Foundation

actor SetupStore {
  typealias ObservationClosure = (Event) -> Void
  enum Event {
    case didUpdateSetupIsFinished
  }
  
  private let setupService: SetupService
  
  init(setupService: SetupService) {
    self.setupService = setupService
  }
  
  var isSetupFinished: Bool {
    setupService.isSetupFinished
  }
  
  func setSetupIsFinished() throws {
    try setupService.setSetupFinished()
    observations.values.forEach { $0(.didUpdateSetupIsFinished) }
  }

  private var observations = [UUID: ObservationClosure]()
  
  func addEventObserver<T: AnyObject>(_ observer: T,
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
