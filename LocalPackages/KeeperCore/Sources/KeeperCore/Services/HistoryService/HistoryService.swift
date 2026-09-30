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
    enum CacheNamespace {
        case allEvents
        case tronUSDT
        case tronTRX

        var cacheKeySuffix: String {
            switch self {
            case .allEvents:
                return "history-all-events"
            case .tronUSDT:
                return "history-tron-usdt"
            case .tronTRX:
                return "history-tron-trx"
            }
        }
    }

    private let apiProvider: APIProvider
    private let repository: HistoryRepository
    private let cacheNamespace: CacheNamespace?

    init(
        apiProvider: APIProvider,
        repository: HistoryRepository,
        cacheNamespace: CacheNamespace? = nil
    ) {
        self.apiProvider = apiProvider
        self.repository = repository
        self.cacheNamespace = cacheNamespace
    }

    func cachedEvents(wallet: Wallet) throws -> [HistoryEvent] {
        try repository.getEvents(forKey: cacheKey(wallet: wallet))
    }

    func cachedEvents(wallet: Wallet, jettonMasterAddress: Address) throws -> [HistoryEvent] {
        try repository.getEvents(
            forKey: cacheKey(wallet: wallet, jettonMasterAddress: jettonMasterAddress)
        )
    }

    func saveEvents(events: [HistoryEvent], wallet: Wallet) throws {
        try repository.saveEvents(events: events, forKey: cacheKey(wallet: wallet))
    }

    func saveEvents(events: [HistoryEvent], jettonMasterAddress: Address, wallet: Wallet) throws {
        try repository.saveEvents(
            events: events,
            forKey: cacheKey(wallet: wallet, jettonMasterAddress: jettonMasterAddress)
        )
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

    private func cacheKey(
        wallet: Wallet
    ) throws -> String {
        let baseKey = try wallet.friendlyAddress.toString()
        guard let cacheNamespace else {
            return baseKey
        }
        return baseKey + ":" + cacheNamespace.cacheKeySuffix
    }

    private func cacheKey(
        wallet: Wallet,
        jettonMasterAddress: Address
    ) throws -> String {
        let baseKey = try wallet.friendlyAddress.toString()
        return baseKey + ":" + jettonMasterAddress.toRaw()
    }
}
