import Foundation
import TonSwift

open class Store<State: Equatable> {
  public struct StateUpdate {
    public let newState: State
    public init(newState: State) {
      self.newState = newState
    }
  }
  
  private static var queueName: String {
    String(describing: Self.self)
  }

  public typealias ObservationClosure = (_ newState: State, _ oldState: State?) -> Void
  
  private var observations = [UUID: ObservationClosure]()

  private let queue = DispatchQueue(label: "\(queueName)SyncQueue")
  
  private var state: State {
    didSet {
      guard state != oldValue else { return }
      observations.forEach { $0.value(state, oldValue) }
    }
  }
  
  public init(state: State) {
    self.state = state
  }
  
  public func getState() -> State {
    queue.sync {
      let state = self.state
      return state
    }
  }
  
  public func getState() async -> State {
    await withCheckedContinuation { continuation in
      queue.async {
        let state = self.state
        continuation.resume(returning: state)
      }
    }
  }
  
  public func updateState(_ update: @escaping (State) -> StateUpdate?) async {
    await withCheckedContinuation { continuation in
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
                                        closure: @escaping (T, _ newState: State, _ oldState: State?) -> Void) {
    let operation = {
      let id = UUID()
      let handler: ObservationClosure = { [weak self, weak observer] newState, oldState in
        guard let observer else {
          self?.removeObservation(key: id)
          return
        }
        closure(observer, newState, oldState)
      }
      self.observations[id] = handler
      if notifyOnAdded {
        let state = self.state
        handler(state, nil)
      }
    }
    
    queue.async(execute: operation)
  }
  
  private func removeObservation(key: UUID) {
    observations.removeValue(forKey: key)
  }
}
