//
//  AppStateManager.swift
//  Tonkeeper
//
//  Created by Grigory on 20.9.23..
//

import UIKit

protocol AppStateTrackerObserver: AnyObject {
  func didUpdateState(_ state: AppStateTracker.State)
}

final class AppStateTracker {
  
  enum State {
    case becomeActive
    case resignActive
    case enterBackground
  }
  
  struct AppStateTrackerObserverWrapper {
    weak var observer: AppStateTrackerObserver?
  }
  
  private var resignActiveNotificationToken: Any?
  private var becomeActiveNotificationToken: Any?
  private var enterBackgroundNotificationToken: Any?
  private var observers = [AppStateTrackerObserverWrapper]()
  
  init() {
    becomeActiveNotificationToken = NotificationCenter
      .default
      .addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] notification in
        self?.notifyObservers(.becomeActive)
      }
    
    resignActiveNotificationToken = NotificationCenter
      .default
      .addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] notification in
        self?.notifyObservers(.resignActive)
      }
    
    enterBackgroundNotificationToken = NotificationCenter
      .default
      .addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] notification in
        self?.notifyObservers(.enterBackground)
    }
  }
  
  deinit {
    if let resignActiveNotificationToken = resignActiveNotificationToken {
      NotificationCenter.default.removeObserver(resignActiveNotificationToken)
    }
    if let becomeActiveNotificationToken = becomeActiveNotificationToken {
      NotificationCenter.default.removeObserver(becomeActiveNotificationToken)
    }
  }
  
  func addObserver(_ observer: AppStateTrackerObserver) {
    observers.append(.init(observer: observer))
  }
  
  func removeObserver(_ observer: AppStateTrackerObserver) {
    observers = observers.filter { $0.observer !== observer }
  }
}

private extension AppStateTracker {
  func notifyObservers(_ state: State) {
    observers = observers.filter { $0.observer != nil }
    observers.forEach { $0.observer?.didUpdateState(state) }
  }
}
