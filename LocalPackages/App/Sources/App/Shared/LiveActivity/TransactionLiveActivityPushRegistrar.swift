import ActivityKit
import Foundation
import KeeperCore
import TKCore
import TKLogging

/// Gives the server what a transaction Live Activity shows, so the server can bring it to its outcome
/// while the app is not running. Requests go out one at a time in the order asked: the server keeps no
/// trace of an unregistration, so a registration sent late would bring an ended activity back.
@available(iOS 16.2, *)
@MainActor
final class TransactionLiveActivityPushRegistrar {
    struct Content: Equatable {
        let walletId: String
        let contentState: Data
        let finalTitles: MultichainLiveActivityRegistration.FinalTitles
        let alertBody: String
    }

    private struct Sent: Equatable {
        let deviceId: String
        let registration: MultichainLiveActivityRegistration
    }

    private let register: (MultichainLiveActivityRegistration) async throws -> MultichainLiveActivityRegistrationResult
    private let unregister: (_ activityId: String) async throws -> Void
    private let deviceId: () async throws -> String
    /// The push token and wallet ids the backend last accepted. They change when the device gets pushes or a binding.
    private let pushSubscription: () -> [String]
    private let now: () -> Date

    private var tokens: [String: String] = [:]
    private var contents: [String: Content] = [:]
    private var sent: [String: Sent] = [:]
    /// The monitor asks on every pass, several times a refresh: the same failed request waits before it goes out again.
    /// The wait matches the background poll, so the background time left still gets a few attempts.
    /// A request the server rejected goes out again only changed, or once the push subscription changes.
    private var failed: [String: (attempt: Sent, pushSubscription: [String], retryAt: Date)] = [:]
    private var ended: Set<String> = []
    /// Unregistered on redaction with nothing sent: until a registration is attempted, there is nothing to remove again.
    private var redactedAway: Set<String> = []
    private var observations: [String: [Task<Void, Never>]] = [:]
    private var tail: Task<Void, Never>?
    private static let retryDelay: TimeInterval = 10

    init(
        register: @escaping (MultichainLiveActivityRegistration) async throws -> MultichainLiveActivityRegistrationResult,
        unregister: @escaping (_ activityId: String) async throws -> Void,
        deviceId: @escaping () async throws -> String,
        pushSubscription: @escaping () -> [String],
        now: @escaping () -> Date = Date.init
    ) {
        self.register = register
        self.unregister = unregister
        self.deviceId = deviceId
        self.pushSubscription = pushSubscription
        self.now = now
    }

    convenience init(authService: MultichainAuthService, appSettings: AppSettings) {
        self.init(
            register: { try await authService.registerLiveActivity($0) },
            unregister: { try await authService.unregisterLiveActivity(activityId: $0) },
            deviceId: { try await authService.deviceId() },
            pushSubscription: {
                [appSettings.multichainPushToken ?? ""] + (appSettings.multichainPushWalletIds ?? []).sorted()
            }
        )
    }

    func track(_ activity: Activity<TransactionLiveActivityAttributes>) {
        let activityId = activity.id
        guard observations[activityId] == nil, !ended.contains(activityId) else { return }
        if let token = activity.pushToken {
            tokenChanged(token, activityId: activityId)
        }
        // `activityStateUpdates` reports changes only, so one that ended before launch would stay registered.
        guard activity.activityState != .ended, activity.activityState != .dismissed else {
            activityEnded(activityId)
            return
        }
        observations[activityId] = [
            Task { [weak self] in
                for await token in activity.pushTokenUpdates {
                    self?.tokenChanged(token, activityId: activityId)
                }
            },
            Task { [weak self] in
                for await state in activity.activityStateUpdates where state == .ended || state == .dismissed {
                    self?.activityEnded(activityId)
                    return
                }
            },
        ]
    }

    func tokenChanged(_ token: Data, activityId: String) {
        guard !ended.contains(activityId) else { return }
        tokens[activityId] = token.map { String(format: "%02x", $0) }.joined()
        enqueue { await $0.sync(activityId) }
    }

    /// `nil` once the activity shows an outcome. The server record stays: over `unknown` the server still brings the real one.
    func contentChanged(_ content: Content?, activityId: String) {
        guard !ended.contains(activityId) else { return }
        contents[activityId] = content
        enqueue { await $0.sync(activityId) }
    }

    /// Replaces the shown state in the server record, so that the record keeps no amounts.
    /// An activity that shows an outcome keeps its record too: over `unknown` the server still brings the real one.
    func redactContent(_ contentState: Data, alertBody: String, activityId: String) {
        guard !ended.contains(activityId) else { return }
        let previous = sent[activityId].flatMap {
            Self.transactionId($0.registration.contentState) == Self.transactionId(contentState) ? $0 : nil
        }
        let content = contents[activityId] ?? previous.map {
            Content(
                walletId: $0.registration.walletId,
                contentState: $0.registration.contentState,
                finalTitles: $0.registration.finalTitles,
                alertBody: $0.registration.alertBody
            )
        }
        guard let content else {
            // A restored activity can have a server record from an earlier launch, also before its token arrives.
            if redactedAway.insert(activityId).inserted {
                enqueue { registrar in
                    if await !registrar.forget(activityId) {
                        registrar.redactedAway.remove(activityId)
                    }
                }
            }
            return
        }
        contentChanged(
            .init(
                walletId: content.walletId,
                contentState: contentState,
                finalTitles: content.finalTitles,
                alertBody: alertBody
            ),
            activityId: activityId
        )
    }

    func activityEnded(_ activityId: String) {
        guard ended.insert(activityId).inserted else { return }
        observations.removeValue(forKey: activityId)?.forEach { $0.cancel() }
        let hadToken = tokens.removeValue(forKey: activityId) != nil
        contents[activityId] = nil
        failed[activityId] = nil
        // A registration from an earlier launch is not in `sent`, but its token is.
        guard hadToken || sent[activityId] != nil else { return }
        enqueue { await $0.forget(activityId) }
    }

    func waitUntilIdle() async {
        while let current = tail {
            await current.value
            if tail == current { return }
        }
    }

    private func enqueue(_ operation: @escaping @MainActor (TransactionLiveActivityPushRegistrar) async -> Void) {
        let previous = tail
        tail = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            await operation(self)
        }
    }

    private func sync(_ activityId: String) async {
        guard !ended.contains(activityId), tokens[activityId] != nil, contents[activityId] != nil
        else { return }
        let deviceId: String
        do {
            deviceId = try await self.deviceId()
        } catch {
            Log.w("Live Activity push: no device id", error: error)
            return
        }
        guard !ended.contains(activityId), let token = tokens[activityId], let content = contents[activityId]
        else { return }
        let registration = MultichainLiveActivityRegistration(
            activityId: activityId,
            pushToken: token,
            walletId: content.walletId,
            contentState: content.contentState,
            finalTitles: content.finalTitles,
            alertBody: content.alertBody
        )
        let next = Sent(deviceId: deviceId, registration: registration)
        guard sent[activityId] != next || failed[activityId] != nil else { return }
        let pushSubscription = pushSubscription()
        if let failure = failed[activityId], failure.attempt == next, failure.pushSubscription == pushSubscription,
           now() < failure.retryAt
        {
            return
        }
        redactedAway.remove(activityId)
        do {
            let result = try await register(registration)
            guard !ended.contains(activityId) else { return }
            switch result {
            case .registered:
                sent[activityId] = next
                failed[activityId] = nil
                Log.i("Live Activity push: registered \(activityId)")
            case let .rejected(reason):
                failed[activityId] = (next, pushSubscription, .distantFuture)
                Log.w("Live Activity push: registration of \(activityId) rejected: \(reason)")
                if await !forgetAnotherTransaction(activityId, than: next) {
                    failed[activityId]?.retryAt = now().addingTimeInterval(Self.retryDelay)
                }
            }
        } catch {
            guard !ended.contains(activityId) else { return }
            failed[activityId] = (next, pushSubscription, now().addingTimeInterval(Self.retryDelay))
            Log.w("Live Activity push: registration of \(activityId) failed", error: error)
            await forgetAnotherTransaction(activityId, than: next)
        }
    }

    /// The server would settle the transaction of its record onto the activity, which already shows another one.
    /// Returns `false` while the server may still hold that record: it stays in `sent`, and the next attempt
    /// unregisters it again.
    @discardableResult
    private func forgetAnotherTransaction(_ activityId: String, than attempt: Sent) async -> Bool {
        guard let previous = sent[activityId],
              Self.transactionId(previous.registration.contentState)
              != Self.transactionId(attempt.registration.contentState)
        else { return true }
        if await forget(activityId) { return true }
        sent[activityId] = previous
        return false
    }

    private static func transactionId(_ contentState: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: contentState) as? [String: Any])?["transactionId"] as? String
    }

    @discardableResult
    private func forget(_ activityId: String) async -> Bool {
        sent[activityId] = nil
        do {
            try await unregister(activityId)
            Log.i("Live Activity push: unregistered \(activityId)")
            return true
        } catch {
            Log.w("Live Activity push: unregistration of \(activityId) failed", error: error)
            return false
        }
    }
}
