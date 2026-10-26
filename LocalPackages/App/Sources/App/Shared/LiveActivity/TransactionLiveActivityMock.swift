import Foundation
import KeeperCore
import PerpsModels

/// Dev-menu fake operations merged into the Live Activity refresh, so the start → update → end path runs
/// without moving funds. Each goes through the same snapshot mapping as its real counterpart. Persisted to
/// survive an app relaunch.
@MainActor
enum TransactionLiveActivityMock {
    nonisolated static let resolveDelay: TimeInterval = 30
    nonisolated static let didChangeNotification = Notification.Name("TransactionLiveActivityMock.didChange")

    nonisolated static func isMock(transactionId: String) -> Bool {
        transactionId.contains("mock-")
    }

    enum Scenario: String, CaseIterable, Codable {
        case sendConfirmed
        case receiveConfirmed
        case swapConfirmed
        case swapFailed
        case bridgeConfirmed
        case receiveDropped
        case perpsDeposit
        case perpsWithdraw
        case perpsOpenLong
        case perpsCloseShort
        case sendPending

        var title: String {
            switch self {
            case .sendConfirmed: "Send TON → sent in 30s"
            case .receiveConfirmed: "Receive TRON USDT → received in 30s"
            case .swapConfirmed: "Swap USDT → TON → swapped in 30s"
            case .swapFailed: "Swap USDT → TON → failed in 30s"
            case .bridgeConfirmed: "Bridge USDT TON → TRON → staged, bridged in 30s"
            case .receiveDropped: "Receive TRON USDT → dropped in 30s"
            case .perpsDeposit: "Perps deposit TON → staged, deposited in 30s"
            case .perpsWithdraw: "Perps withdraw USDC → staged, withdrawn in 30s"
            case .perpsOpenLong: "Perps open BTC long → opened in 30s"
            case .perpsCloseShort: "Perps close ETH short → closed in 30s"
            case .sendPending: "Send TON → pending until resolved"
            }
        }
    }

    struct Entry: Codable {
        let id: String
        let scenario: Scenario
        let startedAt: Date
        var resolvesAt: Date?
    }

    private static let storageKey = "transactionLiveActivity.mockEntries"
    private nonisolated static let ethAddress = "0x71C7656EC7ab88b098defB751B7401B5f6d8976F"

    static func start(_ scenario: Scenario) {
        let now = Date()
        let entry = Entry(
            id: UUID().uuidString,
            scenario: scenario,
            startedAt: now,
            resolvesAt: scenario == .sendPending ? nil : now.addingTimeInterval(resolveDelay)
        )
        entries = entries + [entry]
        notifyRefresh(at: entry.resolvesAt)
    }

    static func resolvePending() {
        let now = Date()
        entries = entries.map { entry in
            guard entry.resolvesAt.map({ $0 > now }) ?? true else { return entry }
            var entry = entry
            entry.resolvesAt = now
            return entry
        }
        notifyRefresh(at: nil)
    }

    @available(iOS 16.2, *)
    static func snapshots(now: Date = Date()) -> [TransactionLiveActivitySnapshot] {
        entries.compactMap { snapshot(for: $0, now: now) }
    }

    @available(iOS 16.2, *)
    nonisolated static func snapshot(for entry: Entry, now: Date) -> TransactionLiveActivitySnapshot? {
        let isResolved = entry.resolvesAt.map { $0 <= now } ?? false
        let stage = stageIndex(of: entry, now: now)
        let operationId = "mock-\(entry.id)"
        let createdAtMillis = Int64(entry.startedAt.timeIntervalSince1970 * 1000)
        switch entry.scenario {
        case .sendConfirmed, .sendPending:
            return activity(entry, type: .send, chain: .ton, outcome: isResolved ? .confirmed : nil)
        case .receiveConfirmed:
            return activity(entry, type: .receive, chain: .tron, outcome: isResolved ? .confirmed : nil)
        case .receiveDropped:
            return activity(entry, type: .receive, chain: .tron, outcome: isResolved ? .dropped : nil)
        case .swapConfirmed:
            return activity(entry, type: .swap, chain: .ton, outcome: isResolved ? .confirmed : nil)
        case .swapFailed:
            return activity(entry, type: .swap, chain: .ton, outcome: isResolved ? .failed : nil)
        case .bridgeConfirmed:
            return bridge(entry, isArriving: stage > 0, isResolved: isResolved)
        case .perpsDeposit:
            return TransactionLiveActivitySnapshot(funding: PerpsPendingFundingOperation(
                operationId: operationId,
                walletId: "mock",
                walletIdentity: "mock",
                environment: "mock",
                createdAtMillis: createdAtMillis,
                details: .deposit(PerpsPendingDeposit(
                    stage: isResolved ? .credited : [.sourcePending, .registrationPending, .registeredPending][stage],
                    route: .crosschainSwap,
                    beneficiary: ethAddress,
                    sourceAsset: PerpsFundingAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9),
                    sourceAmountUnits: "25000000000",
                    targetAsset: PerpsFundingAsset(
                        assetId: "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                        symbol: "USDC",
                        decimals: 6
                    ),
                    creditedAmount: "72.5"
                ))
            ))
        case .perpsWithdraw:
            return TransactionLiveActivitySnapshot(
                funding: PerpsPendingFundingOperation(
                    operationId: operationId,
                    walletId: "mock",
                    walletIdentity: "mock",
                    environment: "mock",
                    createdAtMillis: createdAtMillis,
                    details: .withdraw(PerpsPendingWithdraw(
                        stage: isResolved ? .settled : [.sending, .accepted, .awaitingL1][stage],
                        accountIndex: 0,
                        apiKeyIndex: 0,
                        chainId: 1,
                        assetIndex: 0,
                        routeType: 0,
                        amountUnits: "50000000"
                    ))
                )
            )
        case .perpsOpenLong, .perpsCloseShort:
            let isOpen = entry.scenario == .perpsOpenLong
            return TransactionLiveActivitySnapshot(
                trading: PerpsPendingTradingAction(
                    operationId: operationId,
                    createdAtMillis: createdAtMillis,
                    walletId: "mock",
                    marketId: isOpen ? 1 : 2,
                    side: isOpen ? .long : .short,
                    payload: isOpen ? .open(limitPrice: nil) : .close,
                    expectedBaseSize: isOpen ? 0.015 : 0.5
                ),
                marketSymbol: isOpen ? "BTC" : "ETH",
                status: isResolved ? .confirmed : .pending
            )
        }
    }

    /// A staged scenario spends an equal share of its delay in each of its three stages.
    private nonisolated static func stageIndex(of entry: Entry, now: Date) -> Int {
        guard let resolvesAt = entry.resolvesAt else { return 0 }
        let share = now.timeIntervalSince(entry.startedAt) / max(resolvesAt.timeIntervalSince(entry.startedAt), 1)
        return min(stageCount - 1, max(0, Int(share * Double(stageCount))))
    }

    private nonisolated static let stageCount = 3

    @available(iOS 16.2, *)
    private nonisolated static func bridge(
        _ entry: Entry,
        isArriving: Bool,
        isResolved: Bool
    ) -> TransactionLiveActivitySnapshot? {
        TransactionLiveActivitySnapshot(activity: MultichainActivity(
            activityType: .bridge,
            status: isResolved ? .confirmed : .pending,
            blockTime: entry.startedAt,
            blockNumber: nil,
            fromChain: .ton,
            toChain: .tron,
            walletAddress: "UQDFvVryp7W0BBSI2k7uxh8fWl7wFBVaWxXQ6Lq1u1p8xNZ9",
            direction: .outgoing,
            fromAddress: nil,
            toAddress: nil,
            outToken: token("USDT", chain: .ton),
            outAmount: "25000000",
            outAmountUsd: nil,
            inToken: token("USDT", chain: .tron),
            inAmount: "24800000",
            inAmountUsd: nil,
            feeToken: nil,
            feeAmount: nil,
            feeAmountUsd: nil,
            protocolName: nil,
            txIds: ["ton:mock-\(entry.id)"] + (isArriving || isResolved ? ["tron:mock-arrival-\(entry.id)"] : []),
            isRead: nil
        ))
    }

    @available(iOS 16.2, *)
    private nonisolated static func activity(
        _ entry: Entry,
        type: MultichainActivityType,
        chain: MultichainChain,
        outcome: MultichainActivityStatus?
    ) -> TransactionLiveActivitySnapshot? {
        let isIncoming = type == .receive
        let isSwap = type == .swap
        return TransactionLiveActivitySnapshot(activity: MultichainActivity(
            activityType: type,
            status: outcome ?? .pending,
            blockTime: entry.startedAt,
            blockNumber: nil,
            fromChain: chain,
            toChain: chain,
            walletAddress: chain == .tron
                ? "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
                : "UQDFvVryp7W0BBSI2k7uxh8fWl7wFBVaWxXQ6Lq1u1p8xNZ9",
            direction: isIncoming ? .incoming : .outgoing,
            fromAddress: isIncoming ? "TP1dnHvtnNypf6Paw5t6JGRdEBYWnm2T5t" : nil,
            toAddress: isIncoming ? nil : "UQDGQ7uTp6a4Bq8tCVlq8UlHBq5DBXL4OLllNaD-BdZ_H7CE",
            outToken: isIncoming ? nil : token(isSwap ? "USDT" : "TON", chain: chain),
            outAmount: isSwap ? "12500000" : isIncoming ? nil : "1250000000",
            outAmountUsd: nil,
            inToken: isSwap || isIncoming ? token(isSwap ? "TON" : "USDT", chain: chain) : nil,
            inAmount: isSwap ? "4500000000" : isIncoming ? "72000000" : nil,
            inAmountUsd: nil,
            feeToken: nil,
            feeAmount: nil,
            feeAmountUsd: nil,
            protocolName: nil,
            txIds: ["mock-\(entry.id)"],
            isRead: nil
        ))
    }

    private static var entries: [Entry] {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey),
                  let entries = try? JSONDecoder().decode([Entry].self, from: data)
            else { return [] }
            let earliest = Date().addingTimeInterval(-8 * 60 * 60)
            return entries.filter { $0.startedAt >= earliest }
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: storageKey)
        }
    }

    private nonisolated static func token(_ symbol: String, chain: MultichainChain) -> MultichainAssetDetails {
        MultichainAssetDetails(
            assetId: "mock:\(symbol.lowercased())",
            chain: chain,
            name: symbol,
            symbol: symbol,
            decimals: symbol == "TON" ? 9 : 6,
            image: ""
        )
    }

    /// Stands in for the wallet push a real transaction would produce on start, on each stage and on
    /// resolution.
    private static func notifyRefresh(at resolvesAt: Date?) {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        guard let resolvesAt else { return }
        let delay = max(0, resolvesAt.timeIntervalSinceNow)
        for part in 1 ... stageCount {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay * Double(part) / Double(stageCount) * 1_000_000_000))
                NotificationCenter.default.post(name: didChangeNotification, object: nil)
            }
        }
    }
}
