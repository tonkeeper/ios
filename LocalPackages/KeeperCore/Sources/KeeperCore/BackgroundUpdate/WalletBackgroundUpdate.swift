import Foundation
import TKLogging
import TonStreamingAPIV2

protocol WalletBackgroundUpdateRunning: Sendable {
    func run(
        stateHandler: @escaping @Sendable (BackgroundUpdateConnectionState) async -> Void,
        eventHandler: @escaping @Sendable (BackgroundUpdateEvent) async -> Void
    ) async
}

/// Immutable connection runner. A single `run` operation owns connect, consume and retry, so
/// cancelling its task cancels every stage instead of leaving a detached retry behind.
final class WalletBackgroundUpdate: WalletBackgroundUpdateRunning, @unchecked Sendable {
    typealias StateHandler = @Sendable (BackgroundUpdateConnectionState) async -> Void
    typealias EventHandler = @Sendable (BackgroundUpdateEvent) async -> Void
    typealias Sleep = (_ delay: TimeInterval) async throws -> Void

    private let wallet: Wallet
    private let streamingAPIV2Provider: StreamingAPIV2Provider
    private let sleep: Sleep

    init(
        wallet: Wallet,
        streamingAPIV2Provider: StreamingAPIV2Provider,
        sleep: @escaping Sleep = WalletBackgroundUpdate.defaultSleep
    ) {
        self.wallet = wallet
        self.streamingAPIV2Provider = streamingAPIV2Provider
        self.sleep = sleep
    }

    func run(
        stateHandler: @escaping StateHandler,
        eventHandler: @escaping EventHandler
    ) async {
        while !Task.isCancelled {
            do {
                guard let api = try await streamingAPIV2Provider.api(wallet.network) else {
                    try Task.checkCancellation()
                    await emit(.connected, to: stateHandler)
                    return
                }
                try Task.checkCancellation()
                try await consume(api: api, stateHandler: stateHandler, eventHandler: eventHandler)
                try Task.checkCancellation()
                await emit(.disconnected, to: stateHandler)
            } catch {
                guard !Task.isCancelled, !error.isCancelledError else { return }
                guard !error.isNoConnectionError else {
                    await emit(.noConnection, to: stateHandler)
                    return
                }
                await emit(.disconnected, to: stateHandler)
                do {
                    try await sleep(.retryDelay)
                } catch {
                    return
                }
            }
        }
    }

    private func consume(
        api: TonStreamingAPIV2.StreamingAPI,
        stateHandler: @escaping StateHandler,
        eventHandler: @escaping EventHandler
    ) async throws {
        let address = try wallet.address

        await emit(.connecting, to: stateHandler)

        let request = TonStreamingAPIV2.SseSubscriptionRequest(
            addresses: [address.toRaw()],
            types: [.transactions, .actions, .accountStateChange, .jettonsChange],
            minFinality: .pending
        )

        let stream = try await api.stream(sseSubscriptionRequest: request)
        try Task.checkCancellation()
        await emit(.connected, to: stateHandler)

        for try await payloads in stream {
            try Task.checkCancellation()
            guard let event = payloads.compactMap(backgroundUpdateEvent).last else { continue }
            await eventHandler(event)
        }
    }

    private func emit(
        _ state: BackgroundUpdateConnectionState,
        to stateHandler: StateHandler
    ) async {
        logState(state: state)
        await stateHandler(state)
    }

    private func backgroundUpdateEvent(
        from payload: TonStreamingAPIV2.SseJsonPayload
    ) -> BackgroundUpdateEvent? {
        guard case let .typeStreamEvent(streamEvent) = payload else {
            return nil
        }

        guard case let .typeTransactionsNotification(notification) = streamEvent else {
            return nil
        }

        return backgroundUpdateEvent(from: notification)
    }

    private func backgroundUpdateEvent(
        from notification: TonStreamingAPIV2.TransactionsNotification
    ) -> BackgroundUpdateEvent? {
        let parsedTransactions = notification.transactions.compactMap { transaction in
            parseTransaction(transaction.mapValues(\.value))
        }

        guard let newestTransaction = parsedTransactions.max(by: { $0.lt < $1.lt }) else {
            return nil
        }

        return BackgroundUpdateEvent(
            wallet: wallet,
            lt: newestTransaction.lt,
            txHash: newestTransaction.txHash
        )
    }

    private func parseTransaction(_ object: [String: Any]) -> (lt: Int64, txHash: String)? {
        guard let lt = int64Value(from: object["lt"]) else {
            return nil
        }

        let txHash = stringValue(from: object["tx_hash"]) ?? stringValue(from: object["hash"])
        guard let txHash else {
            return nil
        }

        return (lt: lt, txHash: txHash)
    }

    private func int64Value(from value: Any?) -> Int64? {
        switch value {
        case let value as Int64:
            return value
        case let value as Int:
            return Int64(value)
        case let value as Int32:
            return Int64(value)
        case let value as UInt64:
            return Int64(exactly: value)
        case let value as UInt:
            return Int64(exactly: value)
        case let value as Double:
            return Int64(exactly: value)
        case let value as String:
            return Int64(value)
        default:
            return nil
        }
    }

    private func stringValue(from value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let value as CustomStringConvertible:
            return value.description
        default:
            return nil
        }
    }

    private func logState(state: BackgroundUpdateConnectionState) {
        switch state {
        case .connecting:
            Log.i("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — connecting")
        case .connected:
            Log.i("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — connected")
        case .disconnected:
            Log.i("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — disconnected")
        case .noConnection:
            Log.i("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — no connection")
        }
    }
}

extension WalletBackgroundUpdate {
    static let defaultSleep: Sleep = { delay in
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
}

private extension TimeInterval {
    static let retryDelay: TimeInterval = 3
}
