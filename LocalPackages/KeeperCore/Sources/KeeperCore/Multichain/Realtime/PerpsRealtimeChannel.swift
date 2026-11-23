import Foundation
import TKLogging

private let eventMarket = "perps.market"
private let eventAccount = "perps.account"
private let eventDeposit = "perps.deposit"
private let eventWithdrawal = "perps.withdrawal"

enum PerpsRealtimeEvent: Equatable, Sendable {
    case market(Int64)
    case account
    case deposit
    case withdrawal
}

enum PerpsRealtimeSignal: Equatable, Sendable {
    case subscribed(recovered: Bool)
    case unsubscribed
    case event(PerpsRealtimeEvent)
}

private struct PerpsMarketHint: Decodable {
    struct Payload: Decodable {
        let marketIndex: Int64

        enum CodingKeys: String, CodingKey {
            case marketIndex = "market_index"
        }
    }

    let data: Payload
}

final class PerpsRealtimeChannel: MultichainRealtimeEventHandler {
    private let queue: DispatchQueue
    private let transport: MultichainRealtimeTransport
    private var streams = [String: [UUID: AsyncStream<PerpsRealtimeSignal>.Continuation]]()
    private var connectedWalletId: String?
    private var isRequested = false
    private var subscribedWalletId: String?
    private var seq = MultichainRealtimeSeqFilter()

    init(queue: DispatchQueue, transport: MultichainRealtimeTransport) {
        self.queue = queue
        self.transport = transport
    }

    func signals(walletId: String) -> AsyncStream<PerpsRealtimeSignal> {
        let (stream, continuation) = AsyncStream<PerpsRealtimeSignal>.makeStream()
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            self?.queue.async { [weak self] in
                self?.removeStream(id: id, walletId: walletId)
            }
        }
        queue.async { [weak self] in
            guard let self else {
                continuation.finish()
                return
            }
            self.streams[walletId, default: [:]][id] = continuation
            if self.subscribedWalletId == walletId {
                continuation.yield(.subscribed(recovered: false))
            }
            self.reconcile()
        }
        return stream
    }

    func connectionChanged(walletId: String?) {
        connectedWalletId = walletId
        setSubscribedWalletId(nil)
        reconcile()
    }

    func subscribed(walletId: String, recovered: Bool) {
        guard isRequested, walletId == connectedWalletId else { return }
        subscribedWalletId = walletId
        yield(.subscribed(recovered: recovered), walletId: walletId)
    }

    func unsubscribed(walletId: String) {
        guard subscribedWalletId == walletId else { return }
        setSubscribedWalletId(nil)
    }

    func accept(_ envelope: MultichainRealtimeEnvelope, payload: Data) -> Bool {
        let event: PerpsRealtimeEvent
        switch envelope.event {
        case eventAccount:
            event = .account
        case eventDeposit:
            event = .deposit
        case eventWithdrawal:
            event = .withdrawal
        case eventMarket:
            guard let marketIndex = Self.marketIndex(payload) else { return true }
            event = .market(marketIndex)
        default:
            return false
        }
        guard seq.isNew(envelope.seq, key: Self.seqKey(envelope, event)) else {
            Log.multichain.i("Perps realtime: stale \(envelope.event) \(event) seq:\(envelope.seq)")
            return true
        }
        Log.multichain.i("Perps realtime: \(event) seq:\(envelope.seq)")
        yield(.event(event), walletId: envelope.walletId)
        return true
    }

    private func reconcile() {
        let wanted = connectedWalletId.map { streams[$0] != nil } ?? false
        guard wanted != isRequested else { return }
        isRequested = wanted
        Log.multichain.i("Perps realtime: \(wanted ? "subscribe" : "release") wallet:\(connectedWalletId.map(walletLogId) ?? "none")")
        if !wanted {
            setSubscribedWalletId(nil)
        }
        transport.setPerpsSubscribed(wanted)
    }

    private func removeStream(id: UUID, walletId: String) {
        streams[walletId]?[id] = nil
        if streams[walletId]?.isEmpty == true {
            streams[walletId] = nil
        }
        reconcile()
    }

    private func setSubscribedWalletId(_ walletId: String?) {
        let previous = subscribedWalletId
        subscribedWalletId = walletId
        if let previous, previous != walletId {
            yield(.unsubscribed, walletId: previous)
        }
    }

    private func yield(_ signal: PerpsRealtimeSignal, walletId: String) {
        streams[walletId]?.values.forEach { $0.yield(signal) }
    }

    private static func marketIndex(_ payload: Data) -> Int64? {
        do {
            return try JSONDecoder().decode(PerpsMarketHint.self, from: payload).data.marketIndex
        } catch {
            Log.multichain.w("Realtime perps.market has no market", error: error)
            return nil
        }
    }

    private static func seqKey(_ envelope: MultichainRealtimeEnvelope, _ event: PerpsRealtimeEvent) -> String {
        switch event {
        case let .market(marketIndex): "\(envelope.walletId):\(envelope.event):\(marketIndex)"
        case .account, .deposit, .withdrawal: "\(envelope.walletId):\(envelope.event)"
        }
    }
}
