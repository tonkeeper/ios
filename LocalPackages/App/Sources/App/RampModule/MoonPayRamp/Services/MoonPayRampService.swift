import Foundation
import KeeperCore
import MoonPay
import TKLogging

enum MoonPayRampError: Error, Equatable {
    case notConfigured
    case verificationCancelled
    case verificationFailed(MoonPayConnectionStatus)
    case quoteNotExecutable
    case frame(MoonPayFrameError)
    case paymentCancelled
    case payment(code: String?, reason: String?)
}

enum MoonPayPaymentUpdate: Equatable {
    case started(MoonPayTransaction)
    case pending(MoonPayTransaction)
    case completed(MoonPayTransaction)
    /// Polling ended while MoonPay still reported the transaction as in progress.
    case stillProcessing(MoonPayTransaction)
    case failed(MoonPayRampError)
}

@MainActor
final class MoonPayRampService {
    private let api: MoonPayPlatformAPI
    private let makeSessionToken: (() async throws -> String)?
    private let framePresenter: MoonPayRampFramePresenting
    private var credentials: MoonPayCredentials?
    private var cachedAssets: [MoonPayPlatformAsset]?
    private var cachedTokens: [String: [MoonPayPlatformAsset]] = [:]
    private var connectionTask: Task<MoonPayCredentials, Error>?

    init(
        api: MoonPayPlatformAPI,
        makeSessionToken: (() async throws -> String)?,
        framePresenter: MoonPayRampFramePresenting
    ) {
        self.api = api
        self.makeSessionToken = makeSessionToken
        self.framePresenter = framePresenter
    }

    var isConfigured: Bool {
        makeSessionToken != nil
    }

    func ensureConnected() async throws -> MoonPayCredentials {
        if let credentials, !credentials.isExpired() {
            return credentials
        }
        if let connectionTask {
            return try await connectionTask.value
        }
        let task = Task { [weak self] () throws -> MoonPayCredentials in
            guard let self else { throw MoonPayRampError.notConfigured }
            return try await connect()
        }
        connectionTask = task
        defer { connectionTask = nil }
        let connected = try await task.value
        credentials = connected
        return connected
    }

    func paymentMethods(fiat: String) async throws -> MoonPayPaymentMethods {
        let credentials = try await ensureConnected()
        return try await api.paymentMethods(accessToken: credentials.accessToken, currency: fiat.lowercased())
    }

    var isConnected: Bool {
        credentials.map { !$0.isExpired() } ?? false
    }

    /// The MoonPay asset for one of ours, or `nil` when MoonPay does not sell it.
    func destinationAsset(for details: MultichainAssetDetails) async throws -> MoonPayAsset? {
        let assets = try await sellableAssets()
        var match = MoonPayAssetResolver.match(details, in: assets)
        var tokens: [MoonPayPlatformAsset] = []
        if match == nil {
            tokens = try await deFiTokens(code: details.symbol)
            match = MoonPayAssetResolver.match(details, in: tokens)
        }
        guard let match else {
            Log.multichainRamp.i("moonpay asset: \(details.assetId) is not sold by MoonPay")
            return nil
        }
        return match.quoteReference
    }

    private func deFiTokens(code: String) async throws -> [MoonPayPlatformAsset] {
        if let cached = cachedTokens[code] { return cached }
        let credentials = try await ensureConnected()
        var tokens: [MoonPayPlatformAsset] = []
        var cursor: String?
        repeat {
            let page = try await api.assets(accessToken: credentials.accessToken, source: .defi, code: code, cursor: cursor)
            tokens += page.assets
            cursor = page.nextCursor
        } while cursor != nil && tokens.count < 1000
        cachedTokens[code] = tokens
        return tokens
    }

    private func sellableAssets() async throws -> [MoonPayPlatformAsset] {
        if let cachedAssets { return cachedAssets }
        let credentials = try await ensureConnected()
        var assets: [MoonPayPlatformAsset] = []
        var cursor: String?
        repeat {
            let page = try await api.assets(accessToken: credentials.accessToken, source: .cefi, cursor: cursor)
            assets += page.assets
            cursor = page.nextCursor
        } while cursor != nil && assets.count < 5000
        cachedAssets = assets
        return assets
    }

    func buyQuote(
        fiat: String,
        amount: String,
        destination: MoonPayAsset,
        walletAddress: String,
        paymentMethod: MoonPayPaymentMethodReference
    ) async throws -> MoonPayBuyQuote {
        let credentials = try await ensureConnected()
        let request = MoonPayBuyQuoteRequest(
            source: MoonPayMoney(amount: amount, asset: MoonPayAsset(code: fiat.lowercased())),
            destination: MoonPayMoney(asset: destination),
            wallet: MoonPayWalletReference(address: walletAddress),
            paymentMethod: paymentMethod
        )
        return try await api.buyQuote(accessToken: credentials.accessToken, request: request)
    }

    func pay(quote: MoonPayBuyQuote) -> AsyncStream<MoonPayPaymentUpdate> {
        AsyncStream { continuation in
            Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await run(quote: quote, continuation: continuation)
            }
        }
    }

    func addCard() async throws -> MoonPaySavedCard {
        let credentials = try await ensureConnected()
        var handle: MoonPayRampFrameHandle?
        defer { handle?.dismiss() }
        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            let finish: (Result<MoonPaySavedCard, Error>) -> Void = { result in
                guard !finished else { return }
                finished = true
                continuation.resume(with: result)
            }
            handle = framePresenter.presentModal(
                .addCard(clientToken: credentials.clientToken),
                environment: api.environment,
                onEvent: { event in
                    switch event {
                    case let .complete(.card(card)):
                        finish(.success(card))
                    case .cancelled:
                        finish(.failure(MoonPayRampError.paymentCancelled))
                    case let .error(remote):
                        finish(.failure(MoonPayRampError.frame(.remote(remote))))
                    default:
                        break
                    }
                },
                onFailure: { finish(.failure(MoonPayRampError.frame($0))) },
                onClose: { finish(.failure(MoonPayRampError.paymentCancelled)) }
            )
        }
    }

    func resolveChallenge(_ url: URL) async {
        guard let credentials = try? await ensureConnected() else { return }
        var handle: MoonPayRampFrameHandle?
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var finished = false
            let finish = {
                guard !finished else { return }
                finished = true
                continuation.resume()
            }
            handle = framePresenter.presentModal(
                .challenge(url: url, clientToken: credentials.clientToken),
                environment: api.environment,
                onEvent: { event in
                    switch event {
                    case .complete, .cancelled, .error:
                        finish()
                    default:
                        break
                    }
                },
                onFailure: { _ in finish() },
                onClose: finish
            )
        }
        handle?.dismiss()
    }

    func reset() {
        credentials = nil
        connectionTask?.cancel()
        connectionTask = nil
    }

    private func run(quote: MoonPayBuyQuote, continuation: AsyncStream<MoonPayPaymentUpdate>.Continuation) async {
        Log.multichainRamp.i("moonpay pay: start", extraInfo: ["paymentMethod": quote.paymentMethod?.type ?? "nil"])
        guard quote.executable else {
            Log.multichainRamp.w("moonpay pay: quote is not executable")
            continuation.yield(.failed(.quoteNotExecutable))
            continuation.finish()
            return
        }
        if let payload = MoonPayQuoteSignature.payload(of: quote.signature) {
            let missing = MoonPayQuoteSignature.missingPaymentFrameFields(in: payload)
            if !missing.isEmpty {
                continuation.yield(.failed(.payment(code: "quote", reason: "quote lacks \(missing.joined(separator: ", "))")))
                continuation.finish()
                return
            }
        }
        let credentials: MoonPayCredentials
        do {
            credentials = try await ensureConnected()
        } catch let error as MoonPayRampError {
            Log.multichainRamp.w("moonpay pay: connection failed", error: error)
            continuation.yield(.failed(error))
            continuation.finish()
            return
        } catch {
            Log.multichainRamp.w("moonpay pay: connection failed", error: error)
            continuation.yield(.failed(.notConfigured))
            continuation.finish()
            return
        }

        let externalId = UUID().uuidString.lowercased()
        let frame: MoonPayFrame
        switch quote.paymentMethod?.type {
        case "apple_pay":
            frame = .applePay(clientToken: credentials.clientToken, signature: quote.signature, externalTransactionId: externalId)
        case "card":
            frame = .buy(clientToken: credentials.clientToken, signature: quote.signature, externalTransactionId: externalId)
        default:
            // Every other method is paid inside the MoonPay widget, which has its own UI.
            frame = .widget(clientToken: credentials.clientToken, quoteSignature: quote.signature, externalTransactionId: externalId)
        }

        var challengeHandle: MoonPayRampFrameHandle?
        var frameHandle: MoonPayRampFrameHandle?
        var pollTask: Task<Void, Never>?
        let finishWithTransaction: (MoonPayTransaction) -> Void = { [weak self] transaction in
            challengeHandle?.dismiss()
            if transaction.isFailed {
                continuation.yield(.failed(.payment(code: transaction.failureCode, reason: transaction.failureReason)))
            } else if transaction.isCompleted {
                continuation.yield(.completed(transaction))
            } else {
                continuation.yield(.pending(transaction))
                if let self, let id = transaction.id {
                    pollTask = Task { await self.pollTransaction(transaction: transaction, id: id, continuation: continuation) }
                    return
                }
            }
            continuation.finish()
        }
        let failWithRemote: (MoonPayFrameError.Remote) -> Void = { remote in
            let details = (remote.errors ?? [])
                .map { [$0.field, $0.code, $0.message].compactMap { $0 }.joined(separator: ": ") }
                .joined(separator: "; ")
            let reason = details.isEmpty ? remote.message : "\(remote.message) [\(details)]"
            continuation.yield(.failed(.payment(code: remote.code, reason: reason)))
            continuation.finish()
        }
        let handleChallengeEvent: (MoonPayFrameEvent) -> Void = { event in
            switch event {
            case let .complete(.transaction(transaction)):
                finishWithTransaction(transaction)
            case .complete:
                challengeHandle?.dismiss()
            case let .error(remote):
                challengeHandle?.dismiss()
                failWithRemote(remote)
            case .cancelled:
                challengeHandle?.dismiss()
                continuation.yield(.failed(.paymentCancelled))
                continuation.finish()
            default:
                break
            }
        }
        let handleEvent: (MoonPayFrameEvent) -> Void = { [weak self] event in
            guard let self else { return }
            switch event {
            case let .transactionCreated(transaction):
                continuation.yield(.started(transaction))
            case let .challenge(url):
                challengeHandle = presentChallenge(url, credentials: credentials, onEvent: handleChallengeEvent, onClose: {
                    continuation.yield(.failed(.paymentCancelled))
                    continuation.finish()
                })
            case let .complete(.transaction(transaction)):
                frameHandle?.dismiss()
                finishWithTransaction(transaction)
            case .cancelled:
                frameHandle?.dismiss()
                continuation.yield(.failed(.paymentCancelled))
                continuation.finish()
            case let .error(remote):
                frameHandle?.dismiss()
                failWithRemote(remote)
            default:
                break
            }
        }
        let handleFailure: (MoonPayFrameError) -> Void = { error in
            Log.multichainRamp.w("moonpay pay: frame failed", error: error)
            continuation.yield(.failed(.frame(error)))
            continuation.finish()
        }
        if case .widget = frame {
            frameHandle = framePresenter.presentModal(
                frame,
                environment: api.environment,
                onEvent: handleEvent,
                onFailure: handleFailure,
                onClose: {
                    continuation.yield(.failed(.paymentCancelled))
                    continuation.finish()
                }
            )
        } else {
            frameHandle = framePresenter.runHeadless(
                frame,
                environment: api.environment,
                onEvent: handleEvent,
                onFailure: handleFailure
            )
        }
        continuation.onTermination = { _ in
            Task { @MainActor in
                frameHandle?.dismiss()
                challengeHandle?.dismiss()
                pollTask?.cancel()
            }
        }
    }

    /// Short intervals first, since a card payment usually settles within seconds.
    private static let pollIntervals: [UInt64] = Array(repeating: 3_000_000_000, count: 5)
        + Array(repeating: 5_000_000_000, count: 9)

    /// The payment frame reports `pending` once the card is charged; the final status only exists
    /// on MoonPay's side, so ask for it until the transaction settles.
    private func pollTransaction(
        transaction: MoonPayTransaction,
        id: String,
        continuation: AsyncStream<MoonPayPaymentUpdate>.Continuation
    ) async {
        for interval in Self.pollIntervals {
            try? await Task.sleep(nanoseconds: interval)
            guard !Task.isCancelled else { return }
            do {
                let credentials = try await ensureConnected()
                let details = try await api.transaction(accessToken: credentials.accessToken, id: id)
                Log.multichainRamp.i("moonpay pay: transaction \(details.id) is \(details.status)")
                if details.isCompleted {
                    continuation.yield(.completed(MoonPayTransaction(id: details.id, status: details.status)))
                    continuation.finish()
                    return
                }
                if details.isFailed {
                    let stage = details.failedStage
                    continuation.yield(.failed(.payment(code: stage?.failureReason, reason: stage?.name)))
                    continuation.finish()
                    return
                }
            } catch {
                Log.multichainRamp.w("moonpay pay: transaction poll failed", error: error)
            }
        }
        Log.multichainRamp.w("moonpay pay: transaction polling gave up", extraInfo: ["id": id])
        continuation.yield(.stillProcessing(transaction))
        continuation.finish()
    }

    private func presentChallenge(
        _ url: URL,
        credentials: MoonPayCredentials,
        onEvent: @escaping (MoonPayFrameEvent) -> Void,
        onClose: @escaping () -> Void
    ) -> MoonPayRampFrameHandle {
        framePresenter.presentModal(
            .challenge(url: url, clientToken: credentials.clientToken),
            environment: api.environment,
            onEvent: onEvent,
            onFailure: { error in
                Log.multichainRamp.w("moonpay pay: challenge frame failed", error: error)
                onClose()
            },
            onClose: onClose
        )
    }

    private static let checkConnectionTimeout: TimeInterval = 20

    private func connect() async throws -> MoonPayCredentials {
        guard let makeSessionToken else { throw MoonPayRampError.notConfigured }
        let session = try await makeSessionToken()
        let checkKeyPair = MoonPayKeyPair()
        let (checkResult, checkCredentials) = try await awaitConnection(keyPair: checkKeyPair, timeout: Self.checkConnectionTimeout) { onEvent, onFailure in
            self.framePresenter.runHeadless(
                .checkConnection(sessionToken: session, publicKeyHex: checkKeyPair.publicKeyHex),
                environment: self.api.environment,
                onEvent: onEvent,
                onFailure: onFailure
            )
        }
        Log.multichainRamp.i("moonpay connection: \(checkResult.status), customer \(checkResult.customer?.id ?? "none")")
        switch checkResult.status {
        case .active:
            if let checkCredentials { return checkCredentials }
            throw MoonPayRampError.verificationFailed(.failed)
        case .connectionRequired, .termsAcceptanceRequired:
            guard let clientToken = checkCredentials?.clientToken else {
                throw MoonPayRampError.verificationFailed(checkResult.status)
            }
            return try await connectInteractively(clientToken: clientToken)
        case .pending, .unavailable, .failed:
            throw MoonPayRampError.verificationFailed(checkResult.status)
        }
    }

    private func connectInteractively(clientToken: String) async throws -> MoonPayCredentials {
        let keyPair = MoonPayKeyPair()
        let (result, credentials) = try await awaitConnection(keyPair: keyPair, interactive: true) { onEvent, onFailure in
            self.framePresenter.presentModal(
                .connect(clientToken: clientToken, publicKeyHex: keyPair.publicKeyHex),
                environment: self.api.environment,
                onEvent: onEvent,
                onFailure: onFailure,
                onClose: { onFailure(.loadFailed("closed")) }
            )
        }
        guard result.status == .active, let credentials else {
            throw MoonPayRampError.verificationFailed(result.status)
        }
        return credentials
    }

    private func awaitConnection(
        keyPair: MoonPayKeyPair,
        interactive: Bool = false,
        timeout: TimeInterval? = nil,
        start: (@escaping (MoonPayFrameEvent) -> Void, @escaping (MoonPayFrameError) -> Void) -> MoonPayRampFrameHandle
    ) async throws -> (MoonPayConnectionResult, MoonPayCredentials?) {
        var handle: MoonPayRampFrameHandle?
        defer { handle?.dismiss() }
        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            let finish: (Result<(MoonPayConnectionResult, MoonPayCredentials?), Error>) -> Void = { result in
                guard !finished else { return }
                finished = true
                continuation.resume(with: result)
            }
            handle = start(
                { event in
                    switch event {
                    case let .complete(.connection(result)):
                        do {
                            let credentials = try result.encryptedCredentials.map {
                                try MoonPayCredentialsDecryptor.decrypt($0, using: keyPair)
                            }
                            finish(.success((result, credentials)))
                        } catch {
                            finish(.failure(error))
                        }
                    case let .error(remote):
                        finish(.failure(MoonPayRampError.frame(.remote(remote))))
                    default:
                        break
                    }
                },
                { error in
                    if interactive, error == .loadFailed("closed") {
                        finish(.failure(MoonPayRampError.verificationCancelled))
                    } else {
                        finish(.failure(MoonPayRampError.frame(error)))
                    }
                }
            )
            if let timeout {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    finish(.failure(MoonPayRampError.frame(.loadFailed("timed out"))))
                }
            }
        }
    }
}
