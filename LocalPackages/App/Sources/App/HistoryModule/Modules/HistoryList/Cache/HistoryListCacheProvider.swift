import Foundation
import KeeperCore
import TonSwift

protocol HistoryListCacheProvider {
  func getCache(wallet: Wallet) throws -> [AccountEvent]
  func setCache(events: [AccountEvent], wallet: Wallet) throws
}

final class HistoryListAllEventsCacheProvider: HistoryListCacheProvider {
  private let historyService: HistoryService
  
  init(historyService: HistoryService) {
    self.historyService = historyService
  }
  
  func getCache(wallet: Wallet) throws -> [AccountEvent] {
    try historyService.cachedEvents(wallet: wallet)
  }
  
  func setCache(events: [AccountEvent], wallet: Wallet) throws {
    try historyService.saveEvents(events: events, wallet: wallet)
  }
}

final class HistoryListTonEventsCacheProvider: HistoryListCacheProvider {
  private let historyService: HistoryService
  
  init(historyService: HistoryService) {
    self.historyService = historyService
  }
  
  func getCache(wallet: Wallet) throws -> [AccountEvent] {
    let cachedEvents = try historyService.cachedEvents(wallet: wallet)
    let filteredEvents = cachedEvents.compactMap { event -> AccountEvent? in
      let filteredActions = event.actions.compactMap { action -> AccountEventAction? in
        guard case .tonTransfer = action.type else { return nil }
        return action
      }
      guard !filteredActions.isEmpty else { return nil }
      return AccountEvent(
        eventId: event.eventId,
        date: event.date,
        account: event.account,
        isScam: event.isScam,
        isInProgress: event.isInProgress,
        fee: event.fee,
        actions: filteredActions
      )
    }
    return filteredEvents
  }
  
  func setCache(events: [AccountEvent], wallet: Wallet) throws {
    try historyService.saveEvents(events: events, wallet: wallet)
  }
}

final class HistoryListJettonEventsCacheProvider: HistoryListCacheProvider {
  private let jettonInfo: JettonInfo
  private let historyService: HistoryService
  
  init(jettonInfo: JettonInfo,
       historyService: HistoryService) {
    self.jettonInfo = jettonInfo
    self.historyService = historyService
  }
  
  func getCache(wallet: Wallet) throws -> [AccountEvent] {
    try historyService.cachedEvents(
      wallet: wallet,
      jettonInfo: jettonInfo
    )
  }
  
  func setCache(events: [AccountEvent], wallet: Wallet) throws {
    try historyService.saveEvents(events: events, jettonInfo: jettonInfo, wallet: wallet)
  }
}
