import Foundation
import TonAPI
import TonSwift

public protocol HistoryService {
  func cachedEvents(wallet: Wallet) throws -> [AccountEvent]
  func cachedEvents(wallet: Wallet, jettonInfo: JettonInfo) throws -> [AccountEvent]
  func saveEvents(events: [AccountEvent], wallet: Wallet) throws
  func saveEvents(events: [AccountEvent], jettonInfo: JettonInfo, wallet: Wallet) throws
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
  
  func cachedEvents(wallet: Wallet) throws -> [AccountEvent] {
    try repository.getEvents(forKey: wallet.friendlyAddress.toString())
  }
  
  func cachedEvents(wallet: Wallet, jettonInfo: JettonInfo) throws -> [AccountEvent] {
    let key = try wallet.friendlyAddress.toString() + jettonInfo.address.toRaw()
    return try repository.getEvents(forKey: key)
  }
  
  func saveEvents(events: [AccountEvent], wallet: Wallet) throws {
    try repository.saveEvents(events: events, forKey: wallet.friendlyAddress.toString())
  }
  
  func saveEvents(events: [AccountEvent], jettonInfo: JettonInfo, wallet: Wallet) throws {
    let key = try wallet.friendlyAddress.toString() + jettonInfo.address.toRaw()
    try repository.saveEvents(events: events, forKey: key)
  }
  
  func loadEvents(wallet: Wallet,
                  beforeLt: Int64?,
                  limit: Int) async throws -> AccountEvents {
    let events = try await apiProvider.api(wallet.isTestnet).getAccountEvents(
      address: wallet.address,
      beforeLt: beforeLt,
      limit: limit
    )
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
    return events
  }
  
  func loadEvent(wallet: Wallet,
                 eventId: String) async throws -> AccountEvent {
    try await apiProvider.api(wallet.isTestnet).getEvent(address: wallet.address,
                                                         eventId: eventId)
  }
}
