import Foundation
import TonAPI
import TonSwift

protocol HistoryService {
  func cachedEvents(address: Address) throws -> AccountEvents
  func cachedEvents(address: Address, jettonInfo: JettonInfo) throws -> AccountEvents
  func loadEvents(address: Address,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents
  func loadEvents(address: Address,
                  jettonInfo: JettonInfo,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents
  func loadEvent(accountAddress: Address,
                 eventId: String) async throws -> AccountEvent
}

final class HistoryServiceImplementation: HistoryService {
  private let api: API
  private let repository: HistoryRepository
  
  init(api: API,
       repository: HistoryRepository) {
    self.api = api
    self.repository = repository
  }
  
  func cachedEvents(address: Address) throws -> AccountEvents {
    try repository.getEvents(forKey: address.toRaw())
  }
  
  func cachedEvents(address: Address, jettonInfo: JettonInfo) throws -> AccountEvents {
    let key = address.toRaw() + jettonInfo.address.toRaw()
    return try repository.getEvents(forKey: key)
  }
  
  func loadEvents(address: Address,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents {
    let events = try await api.getAccountEvents(
      address: address,
      beforeLt: beforeLt,
      limit: limit
    )
    if events.startFrom == 0 {
      try? repository.saveEvents(events: events, forKey: address.toRaw())
    }
    return events
  }
  
  func loadEvents(address: Address,
                  jettonInfo: JettonInfo,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents {
    let events = try await api.getAccountJettonEvents(
      address: address,
      jettonInfo: jettonInfo,
      beforeLt: beforeLt,
      limit: limit
    )
    if events.startFrom == 0 {
      let key = address.toRaw() + jettonInfo.address.toRaw()
      try? repository.saveEvents(events: events, forKey: key)
    }
    return events
  }
  
  func loadEvent(accountAddress: Address,
                 eventId: String) async throws -> AccountEvent {
    try await api.getEvent(address: accountAddress,
                           eventId: eventId)
  }
}
