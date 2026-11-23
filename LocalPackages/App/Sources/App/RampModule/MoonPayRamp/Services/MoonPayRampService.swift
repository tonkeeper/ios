import Foundation
import KeeperCore
import MoonPay
import TKLogging
import TKUIKit
import UIKit

enum MoonPayRampError: Error, Equatable {
    case notConfigured
    case verificationCancelled
    /// The customer has to sign in to MoonPay again, and the connect was not allowed to ask.
    case signInRequired
    case verificationFailed(MoonPayConnectionStatus)
    case quoteNotExecutable
    case frame(MoonPayFrameError)
    case paymentCancelled
    /// The customer closed the bank's 3DS page: their cancel, even once the purchase started, as
    /// nothing is charged without it.
    case challengeCancelled
    /// A failed payment: MoonPay's `failureCode` of a frame's transaction, or `failureReason` of
    /// a failed transaction stage.
    case payment(code: String?, reason: String?)
    /// A payment frame's `error` event, whose codes are not the transaction's.
    case paymentFrameError(code: String?, reason: String?)
}

enum MoonPayPaymentUpdate: Equatable {
    case started(MoonPayTransaction)
    case pending(MoonPayTransaction)
    case completed(MoonPayTransaction)
    /// MoonPay still reports the transaction as in progress after the quick polls; slower polls go on.
    case stillProcessing(MoonPayTransaction)
    /// MoonPay could not be asked whether the customer paid, or polling gave up on a payment it
    /// took, so the outcome is not known.
    case outcomeUnknown
    /// MoonPay reported how the customer paid; in the widget it can be another method than the quote's.
    case paidWith(methodType: String)
    case failed(MoonPayRampError)
}

@MainActor
final class MoonPayRampService {
    private let api: MoonPayPlatformAPI
    private let makeSessionToken: () async throws -> String
    private let loadPaymentMethodInfo: (() async throws -> [MoonPayPaymentMethodInfo])?
    private let framePresenter: MoonPayRampFramePresenting
    private var credentials: MoonPayCredentials?
    private var cachedPaymentMethodInfo: [MoonPayPaymentMethodInfo]?
    private var cachedAssets: [MoonPayPlatformAsset]?
    private var cachedTokens: [String: [MoonPayPlatformAsset]] = [:]
    private var connectionTask: Task<MoonPayCredentials, Error>?
    /// The client token a silent connect got where MoonPay asked for a sign-in: the sign-in opens
    /// with it while it lives, without another session and check.
    private var pendingSignIn: MoonPayCredentials?

    init(
        api: MoonPayPlatformAPI,
        makeSessionToken: @escaping () async throws -> String,
        loadPaymentMethodInfo: (() async throws -> [MoonPayPaymentMethodInfo])? = nil,
        framePresenter: MoonPayRampFramePresenting
    ) {
        self.api = api
        self.makeSessionToken = makeSessionToken
        self.loadPaymentMethodInfo = loadPaymentMethodInfo
        self.framePresenter = framePresenter
    }

    private func dropCredentials(_ refused: MoonPayCredentials) {
        guard credentials?.accessToken == refused.accessToken else { return }
        credentials = nil
    }

    /// `interactive: false` reconnects only silently and throws `signInRequired` where MoonPay's
    /// sign-in would be presented. An interactive call that is cancelled ends the connect it
    /// started, so a sign-in for a closed screen is not presented.
    func ensureConnected(interactive: Bool = true) async throws -> MoonPayCredentials {
        if let credentials, !credentials.isExpired() {
            return credentials
        }
        while let running = connectionTask {
            do {
                return try await running.value
            } catch {
                // A connect that failed is over, whenever its owner gets to clear the slot: free it
                // now, so the next call, such as a retry, connects again instead of rejoining it.
                if connectionTask == running {
                    connectionTask = nil
                }
                // A silent connect that needs a sign-in: this caller may present it, so it connects
                // itself, or joins another connect that has started meanwhile.
                if case MoonPayRampError.signInRequired = error, interactive { continue }
                // The connect joined was cancelled with the caller that started it, not with this
                // one, and failed of it, such as in a cancelled session request. A MoonPay error,
                // such as a sign-in the user closed, ended it on its own and stands.
                if running.isCancelled, !Task.isCancelled, !(error is MoonPayRampError) { continue }
                throw error
            }
        }
        let task = Task { [weak self] () throws -> MoonPayCredentials in
            guard let self else { throw MoonPayRampError.notConfigured }
            return try await connect(interactive: interactive)
        }
        connectionTask = task
        defer {
            // A caller that started its own connect after this one may own the slot by now.
            if connectionTask == task {
                connectionTask = nil
            }
        }
        // Callers that joined it connect again when it ends this way.
        let connected = try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            if interactive {
                task.cancel()
            }
        }
        credentials = connected
        return connected
    }

    func paymentMethods(fiat: String) async throws -> MoonPayPaymentMethods {
        let credentials = try await ensureConnected()
        return try await api.paymentMethods(accessToken: credentials.accessToken, currency: fiat.lowercased())
    }

    /// A card MoonPay no longer has (404), deleted on another device for one, counts as deleted.
    func deleteCard(id: String) async throws {
        let credentials = try await ensureConnected()
        do {
            try await api.deletePaymentMethod(accessToken: credentials.accessToken, id: id)
        } catch MoonPayAPIError.http(status: 404, _) {
            Log.multichainRamp.i("moonpay card was already deleted")
        }
    }

    /// Display data by method type. Without it the methods are shown with local names, so a failed
    /// request is not an error.
    func paymentMethodInfo() async -> [String: MoonPayPaymentMethodInfo] {
        Dictionary(await paymentMethodInfoList().map { ($0.type, $0) }) { first, _ in first }
    }

    /// The descriptions loaded so far, without asking our backend.
    var cachedPaymentMethodInfoList: [MoonPayPaymentMethodInfo]? {
        cachedPaymentMethodInfo
    }

    /// In our backend's order.
    func paymentMethodInfoList() async -> [MoonPayPaymentMethodInfo] {
        if let cachedPaymentMethodInfo { return cachedPaymentMethodInfo }
        guard let loadPaymentMethodInfo else { return [] }
        do {
            let info = try await loadPaymentMethodInfo()
            cachedPaymentMethodInfo = info
            return info
        } catch {
            Log.multichainRamp.w("moonpay payment method info failed", error: error)
            return []
        }
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

    /// `externalTransactionId` is ours for this attempt: MoonPay keeps it on the transaction, and
    /// the deposit funnel joins its events with it. `onOpened` is called, at once, when the
    /// payment's own frame starts: MoonPay's widget opens or a card's payment goes to MoonPay.
    /// Before it nothing reached MoonPay; a sign-in is not the payment.
    func pay(
        quote: MoonPayBuyQuote,
        externalTransactionId: String,
        onOpened: @escaping () -> Void = {}
    ) -> AsyncStream<MoonPayPaymentUpdate> {
        AsyncStream { continuation in
            Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await run(quote: quote, externalId: externalTransactionId, onOpened: onOpened, continuation: continuation)
            }
        }
    }

    static func newExternalTransactionId() -> String {
        UUID().uuidString.lowercased()
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

    /// The Apple Pay button as a frame the screen shows in place of its own button, since Apple Pay
    /// starts only from a tap inside the frame. Its updates begin with that tap.
    func applePayButton(quote: MoonPayBuyQuote, height: CGFloat, cornerRadius: CGFloat) async throws -> MoonPayApplePayButton {
        let credentials = try await paymentCredentials(for: quote)
        let externalId = Self.newExternalTransactionId()
        // Without a size the frame draws a 44 pt button inset by padding; the container must match `height`.
        let settings = [
            "height": "\(Int(height))px",
            "borderRadius": "\(Int(cornerRadius))px",
            "paddingX": "0px",
            "paddingY": "0px",
            "type": "buy",
        ]
        let settingsJSON = (try? JSONSerialization.data(withJSONObject: settings, options: .sortedKeys))
            .flatMap { String(data: $0, encoding: .utf8) }
        let controller = MoonPayFrameViewController(
            frame: .applePay(
                clientToken: credentials.clientToken,
                signature: quote.signature,
                externalTransactionId: externalId,
                theme: MoonPayTheme(rawValue: TKThemeManager.shared.theme.stringDescription),
                applePayButtonSettings: settingsJSON
            ),
            environment: api.environment
        )
        controller.embedInline()
        let (updates, continuation) = AsyncStream<MoonPayPaymentUpdate>.makeStream()
        let session = PaymentSession(service: self, credentials: credentials, continuation: continuation)
        let button = MoonPayApplePayButton(
            controller: controller,
            quote: quote,
            externalTransactionId: externalId,
            updates: updates
        ) {
            continuation.finish()
        }
        controller.didReceiveEvent = { [weak button] event in
            switch event {
            case .ready:
                button?.markReady()
            case .buttonPressed:
                button?.press()
            case let .error(remote) where button?.isPressed == false:
                button?.failToLoad(.remote(remote))
            default:
                break
            }
            session.handle(event)
        }
        controller.didFailToLoad = { [weak button] error in
            session.fail(error)
            button?.failToLoad(error)
        }
        controller.didReportDiagnostic = { message in
            Log.multichainRamp.d("moonpay apple pay frame: \(message)")
        }
        continuation.onTermination = { [weak button] _ in
            Task { @MainActor in
                session.tearDown()
                button?.finish()
            }
        }
        return button
    }

    private func run(
        quote: MoonPayBuyQuote,
        externalId: String,
        onOpened: () -> Void,
        continuation: AsyncStream<MoonPayPaymentUpdate>.Continuation
    ) async {
        Log.multichainRamp.i("moonpay pay: start", extraInfo: ["paymentMethod": quote.paymentMethod?.type ?? "nil"])
        // Installed before the first await: the sheet can close while MoonPay connects, and a
        // payment started after that would have nobody to report to and nothing to stop it.
        let listener = PaymentListener()
        continuation.onTermination = { _ in
            Task { @MainActor in
                listener.end()
            }
        }
        let credentials: MoonPayCredentials
        do {
            credentials = try await paymentCredentials(for: quote)
        } catch {
            continuation.yield(.failed(error as? MoonPayRampError ?? .notConfigured))
            continuation.finish()
            return
        }

        let frame: MoonPayFrame
        // Apple Pay is paid from the button on the ramp screen, see `applePayButton(quote:)`.
        switch quote.paymentMethod?.type {
        case "card":
            frame = .buy(clientToken: credentials.clientToken, signature: quote.signature, externalTransactionId: externalId)
        default:
            // Every other method is paid inside the MoonPay widget, which has its own UI.
            frame = .widget(clientToken: credentials.clientToken, quoteSignature: quote.signature, externalTransactionId: externalId)
        }

        guard !listener.isEnded else {
            Log.multichainRamp.i("moonpay pay: status closed before the payment started")
            return
        }
        let session = PaymentSession(service: self, credentials: credentials, continuation: continuation)
        listener.session = session
        onOpened()
        if case .widget = frame {
            // On MoonPay's clock, which both the list's `startDate` and `createdAt` use.
            let openedAt = Date().addingTimeInterval(quote.serverClockOffset ?? 0)
            session.widgetOpened(at: openedAt)
            session.frameHandle = framePresenter.presentModal(
                frame,
                environment: api.environment,
                onEvent: session.handle,
                onFailure: session.fail,
                onClose: { session.widgetClosed(openedAt: openedAt) }
            )
        } else {
            session.frameHandle = framePresenter.runHeadless(
                frame,
                environment: api.environment,
                onEvent: session.handle,
                onFailure: session.fail
            )
        }
    }

    /// Whether anyone still reads a payment's updates, and the session to stop when they stop.
    @MainActor
    private final class PaymentListener {
        private(set) var isEnded = false
        var session: PaymentSession?

        func end() {
            isEnded = true
            session?.tearDown()
        }
    }

    /// The customer's transactions created since `date`.
    private func transactions(since date: Date) async throws -> [MoonPayTransactionDetails] {
        let credentials = try await ensureConnected()
        return try await api.transactions(
            accessToken: credentials.accessToken,
            startDate: date.addingTimeInterval(-Self.clockSkewAllowance)
        )
    }

    /// Covers a device clock that runs ahead of MoonPay's when the quote gave no offset to correct it.
    private static let clockSkewAllowance: TimeInterval = 120

    /// Checks that a payment frame can take the quote, and connects to open the frame with.
    private func paymentCredentials(for quote: MoonPayBuyQuote) async throws -> MoonPayCredentials {
        guard quote.executable else {
            Log.multichainRamp.w("moonpay pay: quote is not executable")
            throw MoonPayRampError.quoteNotExecutable
        }
        if let payload = MoonPayQuoteSignature.payload(of: quote.signature) {
            let missing = MoonPayQuoteSignature.missingPaymentFrameFields(in: payload)
            if !missing.isEmpty {
                throw MoonPayRampError.payment(code: "quote", reason: "quote lacks \(missing.joined(separator: ", "))")
            }
        }
        do {
            return try await ensureConnected()
        } catch let error as MoonPayRampError {
            Log.multichainRamp.w("moonpay pay: connection failed", error: error)
            throw error
        } catch {
            Log.multichainRamp.w("moonpay pay: connection failed", error: error)
            throw MoonPayRampError.notConfigured
        }
    }

    /// Turns the events of one payment frame, and of the challenge it may open, into updates.
    @MainActor
    private final class PaymentSession {
        var frameHandle: MoonPayRampFrameHandle?

        private weak var service: MoonPayRampService?
        private let credentials: MoonPayCredentials
        private let continuation: AsyncStream<MoonPayPaymentUpdate>.Continuation
        private var challengeHandle: MoonPayRampFrameHandle?
        private var pollTask: Task<Void, Never>?
        /// The transaction `pollTask` follows.
        private var polledId: String?
        /// Hands the poll's updates on while it is the session's poll: one replaced, still mid-request,
        /// must not report its transaction or end the stream.
        private var relayTask: Task<Void, Never>?
        /// The poll's last update, repeated when its transaction is named again.
        private var lastPollUpdate: MoonPayPaymentUpdate?
        private var lookupTask: Task<Void, Never>?
        private var knownTransactionsTask: Task<Set<String>?, Never>?
        private var createdTransaction: MoonPayTransaction?
        private var isTornDown = false
        /// The customer closed the 3DS page and its transaction is being checked: a frame's error
        /// meanwhile, such as the closing page's own, must not take the check's place.
        private var isChallengeClosed = false
        private static let stageFailed = "failed"

        init(
            service: MoonPayRampService,
            credentials: MoonPayCredentials,
            continuation: AsyncStream<MoonPayPaymentUpdate>.Continuation
        ) {
            self.service = service
            self.credentials = credentials
            self.continuation = continuation
        }

        func handle(_ event: MoonPayFrameEvent) {
            Log.multichainRamp.i("moonpay pay: frame event", extraInfo: ["event": event.name])
            switch event {
            case let .transactionCreated(transaction):
                createdTransaction = transaction
                continuation.yield(.started(transaction))
            case let .challenge(url):
                challengeHandle = service?.presentChallenge(
                    url,
                    credentials: credentials,
                    onEvent: { [weak self] in self?.handleChallenge($0) },
                    onFailure: { [weak self] in self?.fail($0) },
                    onClose: { [weak self] in self?.cancelChallenge() }
                )
            case let .complete(.transaction(transaction)):
                frameHandle?.dismiss()
                finish(with: transaction)
            case .cancelled:
                frameHandle?.dismiss()
                cancel()
            case let .error(remote):
                frameHandle?.dismiss()
                fail(remote)
            default:
                break
            }
        }

        func fail(_ error: MoonPayFrameError) {
            guard !isChallengeClosed else { return }
            Log.multichainRamp.w("moonpay pay: frame failed", error: error)
            continuation.yield(.failed(.frame(error)))
            continuation.finish()
        }

        func cancel() {
            // A frame's cancel after the 3DS close does not override the transaction's check.
            guard !isChallengeClosed else { return }
            // MoonPay named the transaction: the payment may still go through, so it is followed
            // like any named one, as a closed widget's is.
            if let createdTransaction, let id = createdTransaction.id {
                guard !isTornDown, lookupTask == nil, pollTask == nil else { return }
                poll(createdTransaction, id: id)
                return
            }
            continuation.yield(.failed(.paymentCancelled))
            continuation.finish()
        }

        /// Before MoonPay names a transaction, a closed 3DS page is the customer's cancel. After, the
        /// bank may already have approved it, so its status is asked, a few times while its 3DS
        /// stage still runs: completed is the outcome, a failed 3DS stage the cancel, a failure
        /// past it the reason, and anything still open unknown rather than a cancel to pay again after.
        func cancelChallenge() {
            challengeHandle?.dismiss()
            guard let transaction = createdTransaction, let id = transaction.id, let service else {
                continuation.yield(.failed(.challengeCancelled))
                continuation.finish()
                return
            }
            guard lookupTask == nil, pollTask == nil, !isTornDown else { return }
            isChallengeClosed = true
            continuation.yield(.pending(transaction))
            lookupTask = Task {
                for attempt in 0 ..< Self.closedChallengeChecks {
                    if attempt > 0 {
                        try? await Task.sleep(nanoseconds: Self.closedChallengeCheckDelay)
                    }
                    guard !Task.isCancelled else { return }
                    do {
                        let details = try await service.transactionDetails(id: id, allowsSignIn: false)
                        guard !Task.isCancelled else { return }
                        if details.isCompleted {
                            settle(details)
                            return
                        }
                        // Its 3DS stage failed: nothing was charged, so it is the cancel.
                        if details.authenticationStage?.status == Self.stageFailed {
                            continuation.yield(.failed(.challengeCancelled))
                            continuation.finish()
                            return
                        }
                        // Failed past its 3DS, such as a decline: the reason, not a cancel.
                        if details.isFailed {
                            settle(details)
                            return
                        }
                        // A 3DS stage still running may be the bank's approval MoonPay has not
                        // recorded yet: asked again, and never taken for a cancel.
                        Log.multichainRamp.i(
                            "moonpay pay: 3DS closed, transaction \(id) is \(details.status)",
                            extraInfo: ["authentication": details.authenticationStage?.status ?? "none"]
                        )
                    } catch {
                        // Retried only for a 3DS stage still running: a request that failed, maybe
                        // after a slow connect, would only keep the sheet waiting longer.
                        guard !Task.isCancelled else { return }
                        Log.multichainRamp.w("moonpay pay: transaction check after 3DS closed failed", error: error)
                        break
                    }
                }
                continuation.yield(.outcomeUnknown)
                continuation.finish()
            }
        }

        private static let closedChallengeChecks = 3
        private static let closedChallengeCheckDelay: UInt64 = 2_000_000_000

        func tearDown() {
            isTornDown = true
            frameHandle?.dismiss()
            challengeHandle?.dismiss()
            pollTask?.cancel()
            relayTask?.cancel()
            lookupTask?.cancel()
            knownTransactionsTask?.cancel()
        }

        /// Notes the transactions that already existed, so the lookup on close takes only one this
        /// widget created: the list cannot be filtered by our `externalTransactionId`. Only those
        /// created before the widget opened count, since a slow answer may already list this one.
        /// `date` is on MoonPay's clock when the quote gave its offset; without it, a device clock
        /// that is off by more than the gap between two attempts can still misplace one. Without
        /// the snapshot the lookup falls back to the time window alone.
        func widgetOpened(at date: Date) {
            knownTransactionsTask = Task { [weak service] in
                guard let service else { return nil }
                return try? Set(
                    await service.transactions(since: date)
                        .filter { ($0.createdAt ?? .distantPast) < date }
                        .map(\.id)
                )
            }
        }

        /// The widget may not report a payment made inside it (seen in sandbox: only `handshake` and
        /// `ready` arrive), so closing it is a cancellation only when MoonPay has no new transaction.
        func widgetClosed(openedAt: Date) {
            guard !isTornDown, lookupTask == nil, pollTask == nil else { return }
            if let createdTransaction, let id = createdTransaction.id {
                poll(createdTransaction, id: id)
                return
            }
            // Holds the session: the frame that kept it is gone once the widget closes.
            lookupTask = Task {
                guard let service else {
                    continuation.finish()
                    return
                }
                let known = await knownTransactionsTask?.value ?? nil
                var lastError: Error?
                for attempt in 0 ..< Self.lookupAttempts {
                    if attempt > 0 {
                        try? await Task.sleep(nanoseconds: Self.lookupRetryDelay)
                    }
                    guard !Task.isCancelled else { return }
                    // The frame named the transaction meanwhile: that one is followed.
                    if followNamedTransaction() { return }
                    do {
                        let created = try await service.transactions(since: openedAt)
                            .filter { !(known?.contains($0.id) ?? false) }
                            .max { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
                        guard !Task.isCancelled else { return }
                        // The list may not show a just-made transaction yet, so an empty answer is
                        // a cancellation only on the last attempt.
                        guard created != nil || attempt == Self.lookupAttempts - 1 else { continue }
                        Log.multichainRamp.i(
                            "moonpay pay: widget closed",
                            extraInfo: ["transaction": created?.id ?? "none", "status": created?.status ?? "none"]
                        )
                        if followNamedTransaction() {
                            return
                        } else if let created {
                            settle(created)
                        } else {
                            continuation.yield(.failed(.paymentCancelled))
                            continuation.finish()
                        }
                        return
                    } catch {
                        lastError = error
                    }
                }
                // A finish that cancelled the lookup follows its transaction itself.
                guard !Task.isCancelled else { return }
                if followNamedTransaction() { return }
                Log.multichainRamp.w("moonpay pay: transaction lookup after the widget closed failed", error: lastError)
                // The customer may have paid, so this must not read as a failure to try again after.
                continuation.yield(.outcomeUnknown)
                continuation.finish()
            }
        }

        /// Polls the transaction the frame named, if it did; true when it is followed, by this call
        /// or a poll already running.
        private func followNamedTransaction() -> Bool {
            guard pollTask == nil else { return true }
            guard let createdTransaction, let id = createdTransaction.id else { return false }
            poll(createdTransaction, id: id)
            return true
        }

        private static let lookupAttempts = 3
        private static let lookupRetryDelay: UInt64 = 2_000_000_000

        private func handleChallenge(_ event: MoonPayFrameEvent) {
            switch event {
            case let .complete(.transaction(transaction)):
                finish(with: transaction)
            case .complete:
                challengeHandle?.dismiss()
            case let .error(remote):
                challengeHandle?.dismiss()
                guard !isChallengeClosed else { return }
                fail(remote)
            case .cancelled:
                cancelChallenge()
            default:
                break
            }
        }

        private func finish(with transaction: MoonPayTransaction) {
            challengeHandle?.dismiss()
            // MoonPay's own outcome is what the check after a 3DS close was looking for: it ends the
            // check, and with it the muting of the frames' errors and cancel.
            lookupTask?.cancel()
            lookupTask = nil
            isChallengeClosed = false
            if transaction.isFailed {
                continuation.yield(.failed(.payment(code: transaction.failureCode, reason: transaction.failureReason)))
            } else if transaction.isCompleted {
                continuation.yield(.completed(transaction))
            } else if let id = transaction.id {
                poll(transaction, id: id)
                return
            } else {
                continuation.yield(.pending(transaction))
            }
            continuation.finish()
        }

        private func settle(_ details: MoonPayTransactionDetails) {
            let transaction = MoonPayTransaction(id: details.id, status: details.status)
            if let methodType = details.paymentMethodType {
                continuation.yield(.paidWith(methodType: methodType))
            }
            if details.isFailed {
                let stage = details.failedStage
                continuation.yield(.failed(.payment(code: stage?.failureReason, reason: stage?.name)))
                continuation.finish()
            } else if details.isCompleted {
                continuation.yield(.completed(transaction))
                continuation.finish()
            } else {
                poll(transaction, id: details.id)
            }
        }

        /// One poll per session. The same transaction named again only puts the sheet back to
        /// pending; another one takes over, as the frame's id is MoonPay's own while the
        /// widget-close lookup only guesses.
        private func poll(_ transaction: MoonPayTransaction, id: String) {
            guard !isTornDown else { return }
            if pollTask != nil {
                guard polledId != id else {
                    // Still processing stays so: the poll says it only once.
                    continuation.yield(lastPollUpdate ?? .pending(transaction))
                    return
                }
                pollTask?.cancel()
                relayTask?.cancel()
            }
            polledId = id
            lastPollUpdate = .pending(transaction)
            continuation.yield(.pending(transaction))
            guard let service else {
                continuation.finish()
                return
            }
            let (relay, relayContinuation) = AsyncStream<MoonPayPaymentUpdate>.makeStream()
            pollTask = Task {
                await service.pollTransaction(transaction: transaction, id: id, continuation: relayContinuation)
                relayContinuation.finish()
            }
            relayTask = Task { [weak self] in
                for await update in relay {
                    guard let self, !Task.isCancelled, polledId == id else { return }
                    if case .paidWith = update {} else {
                        lastPollUpdate = update
                    }
                    continuation.yield(update)
                }
                guard let self, !Task.isCancelled, polledId == id else { return }
                continuation.finish()
            }
        }

        private func fail(_ remote: MoonPayFrameError.Remote) {
            guard !isChallengeClosed else { return }
            let details = (remote.errors ?? [])
                .map { [$0.field, $0.code, $0.message].compactMap { $0 }.joined(separator: ": ") }
                .joined(separator: "; ")
            let reason = details.isEmpty ? remote.message : "\(remote.message) [\(details)]"
            continuation.yield(.failed(.paymentFrameError(code: remote.code, reason: reason)))
            continuation.finish()
        }
    }

    /// A look at a transaction; without `allowsSignIn` the connect it may need is silent.
    func transactionDetails(id: String, allowsSignIn: Bool) async throws -> MoonPayTransactionDetails {
        let credentials = try await ensureConnected(interactive: allowsSignIn)
        do {
            return try await api.transaction(accessToken: credentials.accessToken, id: id)
        } catch MoonPayAPIError.http(status: 401, _) {
            // MoonPay refused a token that has not expired here: a device clock behind
            // MoonPay's, or a token revoked early. One silent connect settles it; a sign-in
            // over the sheet is not worth a status check.
            dropCredentials(credentials)
            let fresh = try await ensureConnected(interactive: false)
            return try await api.transaction(accessToken: fresh.accessToken, id: id)
        }
    }

    private func pollTransaction(
        transaction: MoonPayTransaction,
        id: String,
        continuation: AsyncStream<MoonPayPaymentUpdate>.Continuation
    ) async {
        let poller = MoonPayTransactionPoller(fetch: { [weak self] id, allowsSignIn in
            guard let self else { throw CancellationError() }
            return try await transactionDetails(id: id, allowsSignIn: allowsSignIn)
        })
        await poller.poll(transaction: transaction, id: id, continuation: continuation)
    }

    private func presentChallenge(
        _ url: URL,
        credentials: MoonPayCredentials,
        onEvent: @escaping (MoonPayFrameEvent) -> Void,
        onFailure: @escaping (MoonPayFrameError) -> Void,
        onClose: @escaping () -> Void
    ) -> MoonPayRampFrameHandle {
        framePresenter.presentModal(
            .challenge(url: url, clientToken: credentials.clientToken),
            environment: api.environment,
            onEvent: onEvent,
            onFailure: { error in
                Log.multichainRamp.w("moonpay pay: challenge frame failed", error: error)
                onFailure(error)
            },
            onClose: onClose,
            closesAtTap: true
        )
    }

    private static let checkConnectionTimeout: TimeInterval = 20

    private static let pendingSignInMargin: TimeInterval = 60

    private func connect(interactive: Bool) async throws -> MoonPayCredentials {
        if interactive, let pending = pendingSignIn {
            // Used once: MoonPay does not say a client token survives a connect frame that was
            // shown, and a rejected one would fail the sign-in instead of costing a new check.
            pendingSignIn = nil
            if !pending.isExpired(at: Date().addingTimeInterval(Self.pendingSignInMargin)) {
                try Task.checkCancellation()
                return try await connectInteractively(clientToken: pending.clientToken)
            }
        }
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
            guard interactive else {
                pendingSignIn = checkCredentials
                throw MoonPayRampError.signInRequired
            }
            try Task.checkCancellation()
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
                            // Credentials that do not decrypt will not on a retry either; callers
                            // handle a connect failure, not the decryptor's own error.
                            Log.multichainRamp.e("moonpay connection: credentials failed to decrypt", error: error)
                            finish(.failure(MoonPayRampError.verificationFailed(.failed)))
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
