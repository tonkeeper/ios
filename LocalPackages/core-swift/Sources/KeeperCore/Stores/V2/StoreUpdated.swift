import Foundation

open class StoreUpdated<State: Equatable> {
  public typealias ObservationClosure = (_ newState: State, _ oldState: State) -> Void
  public struct StateUpdate {
    public let newState: State
    public init(newState: State) {
      self.newState = newState
    }
  }
  
  private static var typeName: String {
    String(describing: Self.self)
  }
  
  private let queue = DispatchQueue(label: "\(typeName)Queue")
  private var didSetInitialState = false {
    didSet {
      print("Log 🪵: \(Self.typeName) didSetInitialState = \(didSetInitialState)")
    }
  }
  private var observations = [UUID: ObservationClosure]()
  private var _state: State
  private var state: State {
    get {
      setInitialStateIfNeed()
      return _state
    }
    set {
      let oldValue = _state
      _state = newValue
      guard oldValue != newValue else { return }
      observations.forEach { $0.value(newValue, oldValue) }
    }
  }
  
  public init(state: State) {
    self._state = state
  }
  
  public func getState() -> State {
    queue.sync {
      return state
    }
  }
  
  public func getState(completion: @escaping (State) -> Void) {
    queue.async {
      let state = self.state
      completion(state)
    }
  }
  
  public func getState() async -> State {
    await withUnsafeContinuation { continuation in
      queue.async {
        let state = self.state
        continuation.resume(returning: state)
      }
    }
  }
  
  public func updateState(_ update: @escaping (State) -> StateUpdate?, completion: (() -> Void)? = nil) {
    queue.async {
      guard let update = update(self.state) else {
        completion?()
        return
      }
      guard update.newState != self.state else {
        completion?()
        return
      }
      self.state = update.newState
      completion?()
    }
  }
  
  public func updateState(_ update: @escaping (State) -> StateUpdate?) async {
    await withUnsafeContinuation { continuation in
      queue.async {
        guard let update = update(self.state) else {
          continuation.resume()
          return
        }
        guard update.newState != self.state else {
          continuation.resume()
          return
        }
        self.state = update.newState
        continuation.resume()
      }
    }
  }
  
  public func addObserver<T: AnyObject>(_ observer: T,
                                        notifyOnAdded: Bool = true,
                                        closure: @escaping (T, _ newState: State, _ oldState: State) -> Void) {
    let operation = {
      let id = UUID()
      let handler: ObservationClosure = { [weak self, weak observer] newState, oldState in
        guard let self else { return }
        guard let observer else {
          self.observations.removeValue(forKey: id)
          return
        }
        closure(observer, newState, oldState)
      }
      self.observations[id] = handler
      if notifyOnAdded {
        let state = self.state
        handler(state, state)
      }
    }
    
    queue.async(execute: operation)
  }
  
  open func getInitialState() -> State {
    fatalError("Override to provide initial state")
  }

  private func setInitialStateIfNeed() {
    guard !didSetInitialState else { return }
    _state = getInitialState()
    didSetInitialState = true
  }
}
