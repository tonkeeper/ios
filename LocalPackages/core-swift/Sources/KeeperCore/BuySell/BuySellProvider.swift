import Foundation

public final class BuySellProvider {
  public enum State {
    case none
    case loading
    case fiatMethods(FiatMethods)
  }
  
  public var state: State {
    get {
      return lock.withLock {
        _state
      }
    }
    set {
      var observers = [UUID: () -> Void]()
      lock.withLock {
        observers = self.observers
        _state = newValue
      }
      observers.forEach { $0.value() }
    }
  }
  private var _state: State = .none
  private var loadTask: Task<(), Never>?
  private var observers = [UUID: () -> Void]()
  
  private let lock = NSLock()
  
  private let buySellMethodsService: BuySellMethodsService
  
  init(buySellMethodsService: BuySellMethodsService) {
    self.buySellMethodsService = buySellMethodsService
  }
  
  public func load() {
    loadFiatMethods()
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
  
  private func loadFiatMethods() {
    lock.withLock {
      if loadTask != nil {
        return
      }
      _state = .loading
      let task = Task { [weak self] in
        guard let self else { return }
        let state: State
        do {
          let fiatMethods = try await buySellMethodsService.loadFiatMethods(countryCode: nil)
          state = .fiatMethods(fiatMethods)
        } catch {
          state = .none
        }
        var observers = [UUID: () -> Void]()
        lock.withLock {
          observers = self.observers
          self._state = state
          self.loadTask = nil
        }
        observers.forEach { $0.value() }
      }
      self.loadTask = task
    }
  }
}
