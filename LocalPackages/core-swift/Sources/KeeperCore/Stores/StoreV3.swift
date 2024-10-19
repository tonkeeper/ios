import Foundation

extension DispatchQueue {
  static var storeQueue = DispatchQueue(label: "StoreQueue")
}

open class StoreV3<Event, State> {
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
  private var didSetInitialState = false
  private var observers = [UUID: EventClosure]()
  
  private static var syncQueueName: String {
    "\(String(describing: Self.self))Queue"
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
  
//  @discardableResult
//  public func updateState(_ updateClosure: @escaping (State) -> StateUpdate?) async -> State {
//    return await withCheckedContinuation { continuation in
//      updateState(updateClosure, completion: { updatedState in
//        continuation.resume(returning: updatedState)
//      })
//    }
//  }
//  
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

//extension DispatchQueue {
//  static var storeQueue = DispatchQueue(label: "StoreQueue")
//}
//
//open class StoreV3<Event, State> {
//  public typealias ObserverClosure = (Event) -> Void
//  
//  public struct StateUpdate {
//    public let newState: State
//    public init(newState: State) {
//      self.newState = newState
//    }
//  }
//
//  private static var name: String {
//    (String(describing: Self.self))
//  }
//  private static var syncQueueName: String {
//    "\(name)Queue"
//  }
//  
//  private let queue: DispatchQueue
//  
//  private let lock = NSRecursiveLock()
//  
//  private var _state: State
//  private var state: State {
//    get {
//      lock.lock()
//      if !didSetInitialState {
//        let initialState = initialState
//        _state = initialState
//        didSetInitialState = true
//      }
//
//      let state = _state
//      lock.unlock()
//      return state
//    }
//    set {
//      lock.lock()
//      _state = newValue
//      lock.unlock()
//    }
////    get {
////      setInitialStateIfNeeded()
////      return _state
////    }
////    set {
////      _state = newValue
////    }
//  }
//  
//  init(state: State, storeQueue: DispatchQueue = .storeQueue) {
//    
//    self._state = state
////    self.queue = DispatchQueue(label: StoreV3.syncQueueName, target: storeQueue)
//    self.queue = storeQueue
//  }
//  
//  open var initialState: State {
//    fatalError("Override initial state")
//  }
//  
//  public func getState() -> State {
//    return state
////    queue.sync {
////      return state
////    }
//  }
//  
////  public func getState(completion: @escaping (State) -> Void) {
////    queue.async {
////      completion(self.state)
////    }
////  }
//  
//  public func getState() async -> State {
//    await withUnsafeContinuation { continuation in
//      queue.async {
//        continuation.resume(returning: self.state)
//      }
//    }
//  }
//  
//  public func setState(_ closure: @escaping (State) -> StateUpdate?,
//                       notify: ((State) -> Void)? = nil,
//                       completion: ((State) -> Void)? = nil) {
//    queue.async {
//      guard let update = closure(self.state) else {
//        completion?(self.state)
//        return
//      }
//      
//      let newState = update.newState
//      self.state = newState
//      notify?(newState)
//      completion?(newState)
//    }
//  }
//  
//  @discardableResult
//  public func setState(_ closure: @escaping (State) -> StateUpdate?, 
//                       notify: ((State) -> Void)? = nil) async -> State {
//    await withUnsafeContinuation { continuation in
//      queue.async {
//        guard let update = closure(self.state) else {
//          continuation.resume(returning: self.state)
//          return
//        }
//        let newState = update.newState
//        self.state = newState
//        notify?(newState)
//        continuation.resume(returning: newState)
//      }
//    }
//  }
//  
//  public func sendEvent(_ event: Event) {
//    self.observers.forEach { $0.value(event) }
//  }
//  
//  private var observers = [UUID: ObserverClosure]()
//  public func addObserver<T: AnyObject>(_ observer: T,
//                                        closure: @escaping (T, Event) -> Void) {
//    let operation = {
//      let id = UUID()
//      let observerClosure: ObserverClosure = { [weak self, weak observer] event in
//        guard let self else { return }
//        guard let observer else {
//          self.observers.removeValue(forKey: id)
//          return
//        }
//        closure(observer, event)
//      }
//      self.observers[id] = observerClosure
//    }
//    queue.async(execute: operation)
//  }
//  
//  private var didSetInitialState = false {
//    didSet {
//      print("Log 🪵: \(Self.name) didSetInitialState = \(didSetInitialState)")
//    }
//  }
//  private func setInitialStateIfNeeded() {
//    guard !didSetInitialState else { return }
//    _state = initialState
//    didSetInitialState = true
//  }
//}
