import Foundation

open class StoreV3<Event, State> {
  public typealias ObserverClosure = (Event) -> Void
  
  public struct StateUpdate {
    public let newState: State
    public init(newState: State) {
      self.newState = newState
    }
  }

  private static var name: String {
    (String(describing: Self.self))
  }
  private static var syncQueueName: String {
    "\(name)Queue"
  }
  
  private let queue = DispatchQueue(label: syncQueueName)
  
  private var _state: State
  private var state: State {
    get {
      setInitialStateIfNeeded()
      return _state
    }
    set {
      _state = newValue
    }
  }
  
  init(state: State) {
    self._state = state
  }
  
  open var initialState: State {
    fatalError("Override initial state")
  }
  
  public func getState() -> State {
    queue.sync {
      return state
    }
  }
  
  public func getState(completion: @escaping (State) -> Void) {
    queue.async {
      completion(self.state)
    }
  }
  
  public func getState() async -> State {
    await withUnsafeContinuation { continuation in
      queue.async {
        continuation.resume(returning: self.state)
      }
    }
  }
  
  public func setState(_ closure: @escaping (State) -> StateUpdate?, notify: (() -> Void)? = nil, completion: (() -> Void)? = nil) {
    queue.async {
      guard let update = closure(self.state) else {
        completion?()
        return
      }
      
      self.state = update.newState
      notify?()
      completion?()
    }
  }
  
  public func setState(_ closure: @escaping (State) -> StateUpdate?, notify: (() -> Void)? = nil) async {
    await withUnsafeContinuation { continuation in
      queue.async {
        guard let update = closure(self.state) else {
          continuation.resume()
          return
        }
        
        self.state = update.newState
        notify?()
        continuation.resume()
      }
    }
  }
  
  public func sendEvent(_ event: Event) {
    self.observers.forEach { $0.value(event) }
  }
  
  private var observers = [UUID: ObserverClosure]()
  public func addObserver<T: AnyObject>(_ observer: T,
                                        closure: @escaping (T, Event) -> Void) {
    let operation = {
      let id = UUID()
      let observerClosure: ObserverClosure = { [weak self, weak observer] event in
        guard let self else { return }
        guard let observer else {
          self.observers.removeValue(forKey: id)
          return
        }
        closure(observer, event)
      }
      self.observers[id] = observerClosure
    }
    queue.async(execute: operation)
  }
  
  private var didSetInitialState = false {
    didSet {
      print("Log 🪵: \(Self.name) didSetInitialState = \(didSetInitialState)")
    }
  }
  private func setInitialStateIfNeeded() {
    guard !didSetInitialState else { return }
    _state = initialState
    didSetInitialState = true
  }
}
