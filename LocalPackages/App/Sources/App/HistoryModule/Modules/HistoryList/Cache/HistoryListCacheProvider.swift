import Foundation
import KeeperCore
import TonSwift

protocol HistoryListCacheProvider {
  func getCache(wallet: Wallet) throws -> [HistoryEvent]
  func setCache(events: [HistoryEvent], wallet: Wallet) throws
}

final class HistoryListAllEventsCacheProvider: HistoryListCacheProvider {
  private let historyService: HistoryService
  
  init(historyService: HistoryService) {
    self.historyService = historyService
  }
  
  func getCache(wallet: Wallet) throws -> [HistoryEvent] {
    do {
      return try historyService.cachedEvents(wallet: wallet)
    } catch {
      throw error
    }
  }
  
  func setCache(events: [HistoryEvent], wallet: Wallet) throws {
    do {
      try historyService.saveEvents(events: events, wallet: wallet)
    } catch {
      throw error
    }
  }
}

final class HistoryListTonEventsCacheProvider: HistoryListCacheProvider {
  private let historyService: HistoryService
  
  init(historyService: HistoryService) {
    self.historyService = historyService
  }
  
  func getCache(wallet: Wallet) throws -> [HistoryEvent] {
    let cachedEvents = try historyService.cachedEvents(wallet: wallet)
    let filteredEvents = cachedEvents.compactMap { event -> HistoryEvent? in
      guard case let .tonAccountEvent(accountEvent) = event else { return nil }
      
      let filteredActions = accountEvent.actions.compactMap { action -> AccountEventAction? in
        guard case .tonTransfer = action.type else { return nil }
        return action
      }
      guard !filteredActions.isEmpty else { return nil }
      return .tonAccountEvent(AccountEvent(
        eventId: event.eventId,
        date: event.date,
        account: accountEvent.account,
        isScam: event.isScam,
        isInProgress: accountEvent.isInProgress,
        extra: accountEvent.extra,
        actions: filteredActions
      ))
    }
    return filteredEvents
  }
  
  func setCache(events: [HistoryEvent], wallet: Wallet) throws {
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
  
  func getCache(wallet: Wallet) throws -> [HistoryEvent] {
    try historyService.cachedEvents(
      wallet: wallet,
      jettonInfo: jettonInfo
    )
  }
  
  func setCache(events: [HistoryEvent], wallet: Wallet) throws {
    try historyService.saveEvents(events: events, jettonInfo: jettonInfo, wallet: wallet)
  }
}
