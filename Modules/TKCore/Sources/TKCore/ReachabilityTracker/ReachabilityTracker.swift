//
//  ReachabilityTracker.swift
//  Tonkeeper
//
//  Created by Grigory on 20.9.23..
//

import Foundation
import Network

public protocol ReachabilityTrackerObserver: AnyObject {
  func didUpdateState(_ state: ReachabilityTracker.State)
}

public final class ReachabilityTracker {
  
  public enum State {
    case noInternetConnection
    case connected
  }
  
  struct ReachabilityTrackerObserverWrapper {
    weak var observer: ReachabilityTrackerObserver?
  }
  
  private let pathMonitor = NWPathMonitor()
  public private(set) var state = State.connected {
    didSet {
      guard state != oldValue else { return }
      notifyObservers(state)
    }
  }
  private var observers = [ReachabilityTrackerObserverWrapper]()
  
  init() {
    pathMonitor.start(queue: .main)
    pathMonitor.pathUpdateHandler = { [weak self] path in
      switch path.status {
      case .satisfied:
        self?.state = .connected
      default:
        self?.state = .noInternetConnection
      }
    }
  }
  
  deinit {
    pathMonitor.cancel()
  }
  
  public func addObserver(_ observer: ReachabilityTrackerObserver) {
    observers.append(.init(observer: observer))
  }
  
  public func removeObserver(_ observer: ReachabilityTrackerObserver) {
    observers = observers.filter { $0.observer !== observer }
  }
}

private extension ReachabilityTracker {
  func notifyObservers(_ state: State) {
    observers = observers.filter { $0.observer != nil }
    observers.forEach { $0.observer?.didUpdateState(state) }
  }
}

