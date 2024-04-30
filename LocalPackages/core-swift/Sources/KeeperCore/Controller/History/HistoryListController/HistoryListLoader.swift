import Foundation
import TonSwift

protocol HistoryListLoader {
  func cachedEvents(address: Address) throws -> AccountEvents
  func loadEvents(address: Address, beforeLt: Int64?, limit: Int) async throws -> AccountEvents
  func loadEvent(address: Address, eventId: String) async throws -> AccountEvent
}

final class HistoryListAllEventsLoader: HistoryListLoader {
  private let historyService: HistoryService
  
  init(historyService: HistoryService) {
    self.historyService = historyService
  }
  
  func cachedEvents(address: Address) throws -> AccountEvents {
    try historyService.cachedEvents(address: address)
  }
  
  func loadEvents(address: Address,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents {
    return try await historyService.loadEvents(address: address, beforeLt: beforeLt, limit: limit)
  }
  
  func loadEvent(address: Address,
                 eventId: String) async throws -> AccountEvent {
    return try await historyService.loadEvent(accountAddress: address, eventId: eventId)
  }
}

final class HistoryListTonEventsLoader: HistoryListLoader {
  private let historyService: HistoryService
  
  init(historyService: HistoryService) {
    self.historyService = historyService
  }
  
  func cachedEvents(address: Address) throws -> AccountEvents {
    let cachedEvents = try historyService.cachedEvents(address: address)
    let filteredEvents = cachedEvents.events.compactMap { event -> AccountEvent? in
      let filteredActions = event.actions.compactMap { action -> AccountEventAction? in
        guard case .tonTransfer = action.type else { return nil }
        return action
      }
      guard !filteredActions.isEmpty else { return nil }
      return AccountEvent(
        eventId: event.eventId,
        timestamp: event.timestamp,
        account: event.account,
        isScam: event.isScam,
        isInProgress: event.isInProgress,
        fee: event.fee,
        actions: filteredActions
      )
    }
    
    return AccountEvents(
      address: address,
      events: filteredEvents,
      startFrom: cachedEvents.startFrom,
      nextFrom: cachedEvents.nextFrom
    )
  }
  
  func loadEvents(address: Address,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents {
    let loadedEvents = try await historyService.loadEvents(
      address: address,
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
        timestamp: event.timestamp,
        account: event.account,
        isScam: event.isScam,
        isInProgress: event.isInProgress,
        fee: event.fee,
        actions: filteredActions
      )
    }
    
    return AccountEvents(
      address: address,
      events: filteredEvents,
      startFrom: loadedEvents.startFrom,
      nextFrom: loadedEvents.nextFrom
    )
  }
  
  func loadEvent(address: Address,
                 eventId: String) async throws -> AccountEvent {
    return try await historyService.loadEvent(accountAddress: address, eventId: eventId)
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
  
  func cachedEvents(address: Address) throws -> AccountEvents {
    try historyService.cachedEvents(
      address: address,
      jettonInfo: jettonInfo
    )
  }
  
  func loadEvents(address: Address,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents {
    return try await historyService.loadEvents(
      address: address,
      jettonInfo: jettonInfo,
      beforeLt: beforeLt,
      limit: limit
    )
  }
  
  func loadEvent(address: Address,
                 eventId: String) async throws -> AccountEvent {
    return try await historyService.loadEvent(accountAddress: address, eventId: eventId)
  }
}
