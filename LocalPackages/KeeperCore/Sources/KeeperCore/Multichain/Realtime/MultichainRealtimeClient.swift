import Foundation
import SwiftCentrifuge
import TKLogging

private let realtimeWebSocketURL = "wss://rt.tonkeeper.com/connection/websocket"
private let clientName = "ios"
private let walletChannelPrefix = "wallet:"

protocol MultichainRealtimeTransport: AnyObject {
    func connect(walletId: String)
    func disconnect()
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
    private var subscription: CentrifugeSubscription?
    private var subscriptionDelegate: WalletSubscriptionDelegate?
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

    func connect(walletId: String) {
        syncQueue.async { [weak self] in
            guard let self else { return }
            let client = self.client ?? self.makeClient()
            self.client = client
            self.subscribe(client: client, walletId: walletId)
            client.connect()
        }
    }

    func disconnect() {
        syncQueue.async { [weak self] in
            guard let self else { return }
            if let subscription {
                subscription.unsubscribe()
                client?.removeSubscription(subscription)
            }
            subscription = nil
            subscriptionDelegate = nil
            client?.disconnect()
        }
    }

    private func makeClient() -> CentrifugeClient {
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
                    completion(self.mapTokenResult(result))
                }
            }
        )
        return CentrifugeClient(endpoint: realtimeWebSocketURL, config: config, delegate: self)
    }

    private func subscribe(client: CentrifugeClient, walletId: String) {
        let channel = walletChannelPrefix + walletId
        if let subscription, subscription.channel == channel {
            return
        }
        if let subscription {
            subscription.unsubscribe()
            client.removeSubscription(subscription)
        }
        let delegate = WalletSubscriptionDelegate(walletId: walletId) { [weak self] signal in
            self?.emit(signal)
        }
        subscriptionDelegate = delegate
        let config = CentrifugeSubscriptionConfig(
            tokenGetter: { [weak self] _, completion in
                Task { [weak self] in
                    guard let self else {
                        completion(.failure(CentrifugeError.unauthorized))
                        return
                    }
                    let result = await self.tokenSource.subscriptionToken(walletId: walletId)
                    completion(self.mapTokenResult(result))
                }
            }
        )
        do {
            let subscription = try client.newSubscription(
                channel: channel,
                delegate: delegate,
                config: config
            )
            self.subscription = subscription
            subscription.subscribe()
        } catch {
            Log.multichain.w("Realtime subscription create failed", error: error)
        }
    }

    private func mapTokenResult(_ result: RealtimeTokenResult) -> Result<String, Error> {
        switch result {
        case let .token(value):
            return .success(value)
        case .forbidden:
            return .failure(CentrifugeError.unauthorized)
        case .disabledByBackend:
            syncQueue.async { [weak self] in
                self?.disabledByBackendHandler?()
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

    private func emit(_ signal: MultichainRealtimeSignal) {
        syncQueue.async { [weak self] in
            self?.signalHandler?(signal)
        }
    }
}

extension MultichainRealtimeClient: CentrifugeClientDelegate {
    func onConnecting(_: CentrifugeClient, _ event: CentrifugeConnectingEvent) {
        Log.multichain.d("Realtime connecting: \(event.code) \(event.reason)")
    }

    func onConnected(_: CentrifugeClient, _: CentrifugeConnectedEvent) {
        Log.multichain.d("Realtime connected")
    }

    func onDisconnected(_: CentrifugeClient, _ event: CentrifugeDisconnectedEvent) {
        Log.multichain.d("Realtime disconnected: \(event.code) \(event.reason)")
    }

    func onError(_: CentrifugeClient, _ event: CentrifugeErrorEvent) {
        Log.multichain.w("Realtime client error", error: event.error)
    }
}

private final class WalletSubscriptionDelegate: CentrifugeSubscriptionDelegate {
    private let walletId: String
    private let onSignal: (MultichainRealtimeSignal) -> Void
    private let lock = NSLock()
    private var subscribedBefore = false

    init(walletId: String, onSignal: @escaping (MultichainRealtimeSignal) -> Void) {
        self.walletId = walletId
        self.onSignal = onSignal
    }

    func onSubscribing(_: CentrifugeSubscription, _ event: CentrifugeSubscribingEvent) {
        Log.multichain.d("Realtime subscribing: wallet:\(walletId) \(event.code) \(event.reason)")
        onSignal(.unsubscribed(walletId: walletId))
    }

    func onSubscribed(_: CentrifugeSubscription, _: CentrifugeSubscribedEvent) {
        Log.multichain.d("Realtime subscribed: wallet:\(walletId)")
        lock.lock()
        let wasSubscribed = subscribedBefore
        subscribedBefore = true
        lock.unlock()
        onSignal(.subscribed(walletId: walletId, resubscribed: wasSubscribed))
    }

    func onPublication(_: CentrifugeSubscription, _ event: CentrifugePublicationEvent) {
        onSignal(.publication(walletId: walletId, payload: event.data))
    }

    func onUnsubscribed(_: CentrifugeSubscription, _ event: CentrifugeUnsubscribedEvent) {
        Log.multichain.d("Realtime unsubscribed: wallet:\(walletId) \(event.code) \(event.reason)")
        onSignal(.unsubscribed(walletId: walletId))
    }

    func onError(_: CentrifugeSubscription, _ event: CentrifugeSubscriptionErrorEvent) {
        Log.multichain.w("Realtime subscription error: wallet:\(walletId)", error: event.error)
    }
}
