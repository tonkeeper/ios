import Foundation
import SwiftCentrifuge
import TKLogging

private let clientName = "ios"

protocol MultichainRealtimeTransport: AnyObject {
    func connect(walletId: String, endpoint: URL)
    func disconnect()
    func setPerpsSubscribed(_ subscribed: Bool)
    func setSignalHandler(_ handler: @escaping (MultichainRealtimeSignal) -> Void)
    func setDisabledByBackendHandler(_ handler: @escaping () -> Void)
}

final class MultichainRealtimeClient: MultichainRealtimeTransport {
    private let tokenSource: RealtimeTokenSource
    private let userAgent: String
    private let version: String

    private var signalHandler: ((MultichainRealtimeSignal) -> Void)?
    private var disabledByBackendHandler: (() -> Void)?

    private var client: CentrifugeClient?
    private var clientID = UUID()
    private var walletId: String?
    private var wantsPerps = false
    private var walletSubscription: ChannelSubscription?
    private var perpsSubscription: ChannelSubscription?
    private let syncQueue = DispatchQueue(label: "com.tonkeeper.multichain.realtime")

    init(
        tokenSource: RealtimeTokenSource,
        userAgent: String,
        version: String
    ) {
        self.tokenSource = tokenSource
        self.userAgent = userAgent
        self.version = version
    }

    func setSignalHandler(_ handler: @escaping (MultichainRealtimeSignal) -> Void) {
        syncQueue.async { [weak self] in
            self?.signalHandler = handler
        }
    }

    func setDisabledByBackendHandler(_ handler: @escaping () -> Void) {
        syncQueue.async { [weak self] in
            self?.disabledByBackendHandler = handler
        }
    }

    func connect(walletId: String, endpoint: URL) {
        syncQueue.async { [weak self] in
            guard let self else { return }
            self.teardownClient()
            let client = self.makeClient(endpoint: endpoint)
            self.client = client
            self.walletId = walletId
            Log.multichain.i("Realtime connect: wallet:\(walletLogId(walletId)) \(endpoint.host ?? endpoint.absoluteString)")
            self.walletSubscription = self.subscribe(client: client, walletId: walletId, channel: .wallet)
            self.applyPerpsSubscription()
            client.connect()
        }
    }

    func setPerpsSubscribed(_ subscribed: Bool) {
        syncQueue.async { [weak self] in
            guard let self else { return }
            self.wantsPerps = subscribed
            self.applyPerpsSubscription()
        }
    }

    func disconnect() {
        syncQueue.async { [weak self] in
            guard let self else { return }
            self.teardownClient()
        }
    }

    private func applyPerpsSubscription() {
        if wantsPerps {
            guard perpsSubscription == nil, let client, let walletId else { return }
            perpsSubscription = subscribe(client: client, walletId: walletId, channel: .perps)
        } else if let subscription = perpsSubscription {
            perpsSubscription = nil
            remove(subscription)
        }
    }

    private func remove(_ channel: ChannelSubscription) {
        Log.multichain.i("Realtime unsubscribe: \(channel.delegate.logName)")
        channel.subscription.unsubscribe()
        client?.removeSubscription(channel.subscription)
    }

    private func teardownClient() {
        if client != nil {
            Log.multichain.i("Realtime disconnect")
        }
        clientID = UUID()
        let subscriptions = [walletSubscription, perpsSubscription].compactMap { $0 }
        walletSubscription = nil
        perpsSubscription = nil
        walletId = nil
        subscriptions.forEach(remove)
        client?.disconnect()
        client = nil
    }

    private func makeClient(endpoint: URL) -> CentrifugeClient {
        let clientID = self.clientID
        let config = CentrifugeClientConfig(
            headers: ["User-Agent": userAgent],
            name: clientName,
            version: version,
            useNativeWebSocket: true,
            tokenGetter: { [weak self] _, completion in
                Task { [weak self] in
                    guard let self else {
                        completion(.failure(CentrifugeError.unauthorized))
                        return
                    }
                    let result = await self.tokenSource.connectionToken()
                    completion(self.mapTokenResult(result, clientID: clientID))
                }
            }
        )
        return CentrifugeClient(
            endpoint: endpoint.absoluteString,
            config: config,
            delegate: self
        )
    }

    private func subscribe(client: CentrifugeClient, walletId: String, channel: RealtimeChannel) -> ChannelSubscription? {
        let delegate = ChannelSubscriptionDelegate(walletId: walletId, channel: channel) { [weak self] delegate, signal in
            self?.emit(signal, from: delegate)
        }
        let clientID = self.clientID
        let config = CentrifugeSubscriptionConfig(
            tokenGetter: { [weak self] _, completion in
                Task { [weak self] in
                    guard let self else {
                        completion(.failure(CentrifugeError.unauthorized))
                        return
                    }
                    let result = await self.subscriptionToken(channel: channel, walletId: walletId)
                    completion(self.mapTokenResult(result, clientID: clientID))
                }
            }
        )
        do {
            let subscription = try client.newSubscription(
                channel: channel.name(walletId: walletId),
                delegate: delegate,
                config: config
            )
            subscription.subscribe()
            Log.multichain.i("Realtime subscribe: \(channel.logName(walletId: walletId))")
            return ChannelSubscription(subscription: subscription, delegate: delegate)
        } catch {
            Log.multichain.w("Realtime subscription create failed: \(channel.logName(walletId: walletId))", error: error)
            return nil
        }
    }

    private func subscriptionToken(channel: RealtimeChannel, walletId: String) async -> RealtimeTokenResult {
        switch channel {
        case .wallet:
            await tokenSource.subscriptionToken(walletId: walletId)
        case .perps:
            switch await tokenSource.perpsSubscriptionToken(walletId: walletId) {
            case .disabledByBackend: .forbidden
            case let result: result
            }
        }
    }

    private func mapTokenResult(_ result: RealtimeTokenResult, clientID: UUID) -> Result<String, Error> {
        switch result {
        case let .token(value):
            return .success(value)
        case .forbidden:
            return .failure(CentrifugeError.unauthorized)
        case .disabledByBackend:
            syncQueue.async { [weak self] in
                guard let self, self.clientID == clientID else { return }
                self.disabledByBackendHandler?()
            }
            return .failure(CentrifugeError.unauthorized)
        case let .failure(message):
            Log.multichain.w("Realtime token request failed: \(message)")
            return .failure(NSError(
                domain: "MultichainRealtime",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        }
    }

    private func emit(_ signal: MultichainRealtimeSignal, from delegate: ChannelSubscriptionDelegate) {
        syncQueue.async { [weak self] in
            guard let self,
                  self.walletSubscription?.delegate === delegate || self.perpsSubscription?.delegate === delegate
            else { return }
            self.signalHandler?(signal)
        }
    }
}

extension MultichainRealtimeClient: CentrifugeClientDelegate {
    func onConnecting(_: CentrifugeClient, _ event: CentrifugeConnectingEvent) {
        Log.multichain.i("Realtime connecting: \(event.code) \(event.reason)")
    }

    func onConnected(_: CentrifugeClient, _: CentrifugeConnectedEvent) {
        Log.multichain.i("Realtime connected")
    }

    func onDisconnected(_: CentrifugeClient, _ event: CentrifugeDisconnectedEvent) {
        Log.multichain.i("Realtime disconnected: \(event.code) \(event.reason)")
    }

    func onError(_: CentrifugeClient, _ event: CentrifugeErrorEvent) {
        Log.multichain.w("Realtime client error", error: event.error)
    }
}

private enum RealtimeChannel {
    case wallet
    case perps

    func name(walletId: String) -> String {
        switch self {
        case .wallet: "wallet:\(walletId)"
        case .perps: "perps:\(walletId)"
        }
    }

    func logName(walletId: String) -> String {
        name(walletId: walletLogId(walletId))
    }
}

private struct ChannelSubscription {
    let subscription: CentrifugeSubscription
    let delegate: ChannelSubscriptionDelegate
}

private final class ChannelSubscriptionDelegate: CentrifugeSubscriptionDelegate {
    private let walletId: String
    private let channel: RealtimeChannel
    private let onSignal: (ChannelSubscriptionDelegate, MultichainRealtimeSignal) -> Void
    private let lock = NSLock()
    private var subscribedBefore = false

    init(
        walletId: String,
        channel: RealtimeChannel,
        onSignal: @escaping (ChannelSubscriptionDelegate, MultichainRealtimeSignal) -> Void
    ) {
        self.walletId = walletId
        self.channel = channel
        self.onSignal = onSignal
    }

    var logName: String {
        channel.logName(walletId: walletId)
    }

    private var unsubscribedSignal: MultichainRealtimeSignal {
        switch channel {
        case .wallet: .unsubscribed(walletId: walletId)
        case .perps: .perpsUnsubscribed(walletId: walletId)
        }
    }

    func onSubscribing(_: CentrifugeSubscription, _ event: CentrifugeSubscribingEvent) {
        Log.multichain.i("Realtime subscribing: \(logName) \(event.code) \(event.reason)")
        onSignal(self, unsubscribedSignal)
    }

    func onSubscribed(_: CentrifugeSubscription, _ event: CentrifugeSubscribedEvent) {
        Log.multichain.i("Realtime subscribed: \(logName) recovered:\(event.wasRecovering && event.recovered)")
        lock.lock()
        let wasSubscribed = subscribedBefore
        subscribedBefore = true
        lock.unlock()
        switch channel {
        case .wallet:
            onSignal(self, .subscribed(walletId: walletId, resubscribed: wasSubscribed))
        case .perps:
            onSignal(self, .perpsSubscribed(walletId: walletId, recovered: event.wasRecovering && event.recovered))
        }
    }

    func onPublication(_: CentrifugeSubscription, _ event: CentrifugePublicationEvent) {
        onSignal(self, .publication(walletId: walletId, payload: event.data))
    }

    func onUnsubscribed(_: CentrifugeSubscription, _ event: CentrifugeUnsubscribedEvent) {
        Log.multichain.i("Realtime unsubscribed: \(logName) \(event.code) \(event.reason)")
        onSignal(self, unsubscribedSignal)
    }

    func onError(_: CentrifugeSubscription, _ event: CentrifugeSubscriptionErrorEvent) {
        Log.multichain.w("Realtime subscription error: \(logName)", error: event.error)
    }
}
