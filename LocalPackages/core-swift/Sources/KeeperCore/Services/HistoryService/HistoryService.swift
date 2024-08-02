import Foundation
import TonAPI
import TonSwift

protocol HistoryService {
  func cachedEvents(wallet: Wallet) throws -> AccountEvents
  func cachedEvents(wallet: Wallet, jettonInfo: JettonInfo) throws -> AccountEvents
  func loadEvents(wallet: Wallet,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents
  func loadEvents(wallet: Wallet,
                  jettonInfo: JettonInfo,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents
  func loadEvent(wallet: Wallet,
                 eventId: String) async throws -> AccountEvent
}

final class HistoryServiceImplementation: HistoryService {
  private let apiProvider: APIProvider
  private let repository: HistoryRepository
  
  init(apiProvider: APIProvider,
       repository: HistoryRepository) {
    self.apiProvider = apiProvider
    self.repository = repository
  }
  
  func cachedEvents(wallet: Wallet) throws -> AccountEvents {
    try repository.getEvents(forKey: wallet.friendlyAddress.toString())
  }
  
  func cachedEvents(wallet: Wallet, jettonInfo: JettonInfo) throws -> AccountEvents {
    let key = try wallet.friendlyAddress.toString() + jettonInfo.address.toRaw()
    return try repository.getEvents(forKey: key)
  }
  
  func loadEvents(wallet: Wallet,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents {
    let events = try await apiProvider.api(wallet.isTestnet).getAccountEvents(
      address: wallet.address,
      beforeLt: beforeLt,
      limit: limit
    )
    if events.startFrom == 0 {
      try? repository.saveEvents(events: events, forKey: wallet.friendlyAddress.toString())
    }
    return events
  }
  
  func loadEvents(wallet: Wallet,
                  jettonInfo: JettonInfo,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents {
    let events = try await apiProvider.api(wallet.isTestnet).getAccountJettonEvents(
      address: wallet.address,
      jettonInfo: jettonInfo,
      beforeLt: beforeLt,
      limit: limit
    )
    if events.startFrom == 0 {
      try? repository.saveEvents(
        events: events,
        forKey: wallet.friendlyAddress.toString() + jettonInfo.address.toRaw()
      )
    }
    return events
  }
  
  func loadEvent(wallet: Wallet,
                 eventId: String) async throws -> AccountEvent {
    try await apiProvider.api(wallet.isTestnet).getEvent(address: wallet.address,
                                                         eventId: eventId)
  }
}
