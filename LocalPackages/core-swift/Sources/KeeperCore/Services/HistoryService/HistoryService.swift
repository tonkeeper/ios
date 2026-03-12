import Foundation
import TonAPI
import TonSwift

public protocol HistoryService {
    func cachedEvents(wallet: Wallet) throws -> [HistoryEvent]
    func cachedEvents(wallet: Wallet, jettonMasterAddress: Address) throws -> [HistoryEvent]
    func saveEvents(events: [HistoryEvent], wallet: Wallet) throws
    func saveEvents(events: [HistoryEvent], jettonMasterAddress: Address, wallet: Wallet) throws
    func loadEvents(
        wallet: Wallet,
        beforeLt: Int64?,
        limit: Int
    ) async throws -> AccountEvents
    func loadEvents(
        wallet: Wallet,
        jettonMasterAddress: Address,
        beforeLt: Int64?,
        limit: Int
    ) async throws -> AccountEvents
    func loadEvent(
        wallet: Wallet,
        eventId: String
    ) async throws -> AccountEvent
}

final class HistoryServiceImplementation: HistoryService {
    private let apiProvider: APIProvider
    private let repository: HistoryRepository

    init(
        apiProvider: APIProvider,
        repository: HistoryRepository
    ) {
        self.apiProvider = apiProvider
        self.repository = repository
    }

    func cachedEvents(wallet: Wallet) throws -> [HistoryEvent] {
        try repository.getEvents(forKey: wallet.friendlyAddress.toString())
    }

    func cachedEvents(wallet: Wallet, jettonMasterAddress: Address) throws -> [HistoryEvent] {
        let key = try wallet.friendlyAddress.toString() + jettonMasterAddress.toRaw()
        return try repository.getEvents(forKey: key)
    }

    func saveEvents(events: [HistoryEvent], wallet: Wallet) throws {
        try repository.saveEvents(events: events, forKey: wallet.friendlyAddress.toString())
    }

    func saveEvents(events: [HistoryEvent], jettonMasterAddress: Address, wallet: Wallet) throws {
        let key = try wallet.friendlyAddress.toString() + jettonMasterAddress.toRaw()
        try repository.saveEvents(events: events, forKey: key)
    }

    func loadEvents(
        wallet: Wallet,
        beforeLt: Int64?,
        limit: Int
    ) async throws -> AccountEvents {
        return try await apiProvider.api(wallet.network).getAccountEvents(
            address: wallet.address,
            beforeLt: beforeLt,
            limit: limit
        )
    }

    func loadEvents(
        wallet: Wallet,
        jettonMasterAddress: Address,
        beforeLt: Int64?,
        limit: Int
    ) async throws -> AccountEvents {
        return try await apiProvider.api(wallet.network).getAccountJettonEvents(
            address: wallet.address,
            jettonMasterAddress: jettonMasterAddress,
            beforeLt: beforeLt,
            limit: limit
        )
    }

    func loadEvent(
        wallet: Wallet,
        eventId: String
    ) async throws -> AccountEvent {
        try await apiProvider.api(wallet.network).getEvent(
            address: wallet.address,
            eventId: eventId
        )
    }
}
