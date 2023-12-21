//
//  AuthEventsDaemon.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 27.10.2023.
//

import Foundation
import WalletCoreCore
import WalletCoreKeeper
import TKCore

protocol AuthEventsDaemonObserver: AnyObject {
  func authEventsDaemon(_ daemon: AuthEventsDaemon,
                        didReceiveTonConnectAppRequest appRequest: WalletCoreKeeper.TonConnect.AppRequest,
                        app: TonConnectApp)
}

final class AuthEventsDaemon {
  struct AuthEventsDaemonObserverWrapper {
    weak var observer: AuthEventsDaemonObserver?
  }
  
  private let walletProvider: WalletProvider
  private let transactionsEventDaemon: WalletCoreKeeper.TransactionsEventDaemon
  private let tonConnectEventsDaemon: WalletCoreKeeper.TonConnectEventsDaemon
  private let appStateTracker: AppStateTracker
  private let reachabilityTracker: ReachabilityTracker
  
  private var observers = [AuthEventsDaemonObserverWrapper]()
  
  init(walletProvider: WalletProvider,
       transactionsEventDaemon: WalletCoreKeeper.TransactionsEventDaemon,
       tonConnectEventsDaemon: WalletCoreKeeper.TonConnectEventsDaemon,
       appStateTracker: AppStateTracker,
       reachabilityTracker: ReachabilityTracker) {
    self.walletProvider = walletProvider
    self.transactionsEventDaemon = transactionsEventDaemon
    self.tonConnectEventsDaemon = tonConnectEventsDaemon
    self.appStateTracker = appStateTracker
    self.reachabilityTracker = reachabilityTracker
    
    tonConnectEventsDaemon.addObserver(self)
    appStateTracker.addObserver(self)
    reachabilityTracker.addObserver(self)
  }
  
  func start() {
    startTransactionsObserving()
    startTonConnectObserving()
  }
  
  func stop() {
    stopTransactionsObserving()
    stopTonConnectObserving()
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
    
    
  
  }
  
  func startTonConnectObserving() {
    tonConnectEventsDaemon.startEventsObserving()
  }
  
  func stopTonConnectObserving() {
    tonConnectEventsDaemon.stopEventsObserving()
  }
  
  func startTransactionsObserving() {
    Task {
      let addresses = [try walletProvider.activeWallet.address]
      await transactionsEventDaemon.start(addresses: addresses)
    }
  }
  
  func stopTransactionsObserving() {
    Task {
      await transactionsEventDaemon.stop()
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
    switch appStateTracker.state {
    case .active:
      startTransactionsObserving()
      startTonConnectObserving()
    case .background:
      stopTransactionsObserving()
      stopTonConnectObserving()
    case .resign:
      return
    }
  }
}

// MARK: - ReachabilityTrackerObserver

extension AuthEventsDaemon: ReachabilityTrackerObserver {
  func didUpdateState(_ state: TKCore.ReachabilityTracker.State) {
    switch reachabilityTracker.state {
    case .connected:
      startTransactionsObserving()
      startTonConnectObserving()
    default:
      return
    }
  }
}
