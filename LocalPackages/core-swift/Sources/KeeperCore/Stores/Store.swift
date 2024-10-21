import Foundation

extension DispatchQueue {
  static var storeQueue = DispatchQueue(label: "StoreQueue")
}

open class Store<Event, State> {
  public typealias EventClosure = (Event) -> Void
  
  public struct StateUpdate {
    public let newState: State
    public init(newState: State) {
      self.newState = newState
    }
  }
  
  private(set) public var state: State {
    get {
      lock.lock()
      defer { lock.unlock() }
      setInitialStateIfNeeded()
      return _state
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _state = newValue
    }
  }
  
  private var lock = NSLock()
  private var didSetInitialState = false {
    didSet {
      print("Log 🪵: \(Self.name) didSetInitialState = \(didSetInitialState)")
    }
  }
  private var observers = [UUID: EventClosure]()
  
  private static var name: String {
    (String(describing: Self.self))
  }
  private static var syncQueueName: String {
    "\(name)Queue"
  }
  
  private var _state: State
  private let syncQueue: DispatchQueue
  
  init(state: State, syncTargetQueue: DispatchQueue = .storeQueue) {
    self._state = state
    self.syncQueue = DispatchQueue(label: Self.syncQueueName)
  }
  
  public func createInitialState() -> State {
    fatalError("override createInitialState")
  }
  
  public func getState() -> State {
    state
  }
  
  public func updateState(_ updateClosure: @escaping (State) -> StateUpdate?,
                          completion: ((State) -> Void)?) {
    syncQueue.async {
      let state = self.state
      guard let update = updateClosure(state) else {
        completion?(state)
        return
      }
      let newState = update.newState
      self.state = newState
      completion?(newState)
    }
  }

  public func setState(_ closure: @escaping (State) -> StateUpdate?,
                       notify: ((State) -> Void)? = nil,
                       completion: ((State) -> Void)? = nil) {
  }
  
  public func setState(_ closure: @escaping (State) -> StateUpdate?,
                       notify: ((State) -> Void)? = nil) async {
  }
  
  public func addObserver<T: AnyObject>(_ observer: T,
                                        closure: @escaping (T, Event) -> Void) {
    let operation = {
      let id = UUID()
      let observerClosure: EventClosure = { [weak self, weak observer] event in
        guard let self else { return }
        guard let observer else {
          self.observers.removeValue(forKey: id)
          return
        }
        closure(observer, event)
      }
      self.observers[id] = observerClosure
      
    }
    syncQueue.async(execute: operation)
  }
  
  public func sendEvent(_ event: Event) {
    syncQueue.async { [weak self] in
      guard let self else { return }
      let observers = self.observers
      observers.forEach { $0.value(event) }
    }
  }
  
  private func setInitialStateIfNeeded() {
    guard !didSetInitialState else { return }
    _state = createInitialState()
    didSetInitialState = true
  }
}
