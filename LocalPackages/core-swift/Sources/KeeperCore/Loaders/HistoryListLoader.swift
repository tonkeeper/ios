import Foundation
import TonSwift

protocol HistoryListLoader {
  func loadEvents(wallet: Wallet, beforeLt: Int64?, limit: Int) async throws -> AccountEvents
  func loadEvent(wallet: Wallet, eventId: String) async throws -> AccountEvent
}

final class HistoryListAllEventsLoader: HistoryListLoader {
  private let historyService: HistoryService
  
  init(historyService: HistoryService) {
    self.historyService = historyService
  }
  

  func loadEvents(wallet: Wallet,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents {
    return try await historyService.loadEvents(wallet: wallet, beforeLt: beforeLt, limit: limit)
  }
  
  func loadEvent(wallet: Wallet,
                 eventId: String) async throws -> AccountEvent {
    return try await historyService.loadEvent(wallet: wallet, eventId: eventId)
  }
}

final class HistoryListTonEventsLoader: HistoryListLoader {
  private let historyService: HistoryService
  
  init(historyService: HistoryService) {
    self.historyService = historyService
  }

  func loadEvents(wallet: Wallet,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents {
    let loadedEvents = try await historyService.loadEvents(
      wallet: wallet,
      beforeLt: beforeLt,
      limit: limit
    )
    
    let filteredEvents = loadedEvents.events.compactMap { event -> AccountEvent? in
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
    
    return AccountEvents(
      address: try wallet.address,
      events: filteredEvents,
      startFrom: loadedEvents.startFrom,
      nextFrom: loadedEvents.nextFrom
    )
  }
  
  func loadEvent(wallet: Wallet,
                 eventId: String) async throws -> AccountEvent {
    return try await historyService.loadEvent(wallet: wallet, eventId: eventId)
  }
}

final class HistoryListJettonEventsLoader: HistoryListLoader {
  private let jettonInfo: JettonInfo
  private let historyService: HistoryService
  
  init(jettonInfo: JettonInfo,
       historyService: HistoryService) {
    self.jettonInfo = jettonInfo
    self.historyService = historyService
  }

  func loadEvents(wallet: Wallet,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents {
    return try await historyService.loadEvents(
      wallet: wallet,
      jettonInfo: jettonInfo,
      beforeLt: beforeLt,
      limit: limit
    )
  }
  
  func loadEvent(wallet: Wallet,
                 eventId: String) async throws -> AccountEvent {
    return try await historyService.loadEvent(wallet: wallet, eventId: eventId)
  }
}
