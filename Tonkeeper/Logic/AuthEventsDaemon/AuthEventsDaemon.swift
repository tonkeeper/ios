//
//  AuthEventsDaemon.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 27.10.2023.
//

import Foundation
import WalletCore
import TKCore

protocol AuthEventsDaemonObserver: AnyObject {
  func authEventsDaemon(_ daemon: AuthEventsDaemon,
                        didReceiveTonConnectAppRequest appRequest: WalletCore.TonConnect.AppRequest,
                        app: TonConnectApp)
}

final class AuthEventsDaemon {
  struct AuthEventsDaemonObserverWrapper {
      weak var observer: AuthEventsDaemonObserver?
  }
  
  private let tonConnectEventsDaemon: WalletCore.TonConnectEventsDaemon
  private let appStateTracker: AppStateTracker
  private let reachabilityTracker: ReachabilityTracker
  
  private var observers = [AuthEventsDaemonObserverWrapper]()
  
  init(tonConnectEventsDaemon: WalletCore.TonConnectEventsDaemon,
       appStateTracker: AppStateTracker,
       reachabilityTracker: ReachabilityTracker) {
    self.tonConnectEventsDaemon = tonConnectEventsDaemon
    self.appStateTracker = appStateTracker
    self.reachabilityTracker = reachabilityTracker
    
    tonConnectEventsDaemon.addObserver(self)
    appStateTracker.addObserver(self)
    reachabilityTracker.addObserver(self)
  }
  
  func startObserving() {
    tonConnectEventsDaemon.startEventsObserving()
  }
  
  func stopObserving() {
    tonConnectEventsDaemon.stopEventsObserving()
  }
  
  public func addObserver(_ observer: AuthEventsDaemonObserver) {
      var observers = observers.filter { $0.observer != nil }
      observers.append(.init(observer: observer))
      self.observers = observers
  }
  
  public func removeObserver(_ observer: AuthEventsDaemonObserver) {
      observers = observers.filter { $0.observer !== observer }
  }
}

private extension AuthEventsDaemon {
  func handleStateChange() {
    switch (appStateTracker.state, reachabilityTracker.state) {
    case (.becomeActive, .connected):
      startObserving()
    default:
      stopObserving()
    }
  }
  
  func notifyObservers(appRequest: TonConnect.AppRequest) {
    observers = observers.filter { $0.observer != nil }
    observers.forEach { _ in  }
  }
}

// MARK: - TonConnectEventsDaemonObserver

extension AuthEventsDaemon: TonConnectEventsDaemonObserver {
  func tonConnectEventsDaemonDidReceiveRequest(_ daemon: TonConnectEventsDaemon,
                                               appRequest: TonConnect.AppRequest,
                                               app: TonConnectApp) {
    observers = observers.filter { $0.observer != nil }
    observers.forEach { $0.observer?.authEventsDaemon(
      self,
      didReceiveTonConnectAppRequest: appRequest,
      app: app)
    }
  }
}

// MARK: - AppStateTrackerObserver

extension AuthEventsDaemon: AppStateTrackerObserver {
  func didUpdateState(_ state: TKCore.AppStateTracker.State) {
    handleStateChange()
  }
}

// MARK: - ReachabilityTrackerObserver

extension AuthEventsDaemon: ReachabilityTrackerObserver {
  func didUpdateState(_ state: TKCore.ReachabilityTracker.State) {
    handleStateChange()
  }
}
