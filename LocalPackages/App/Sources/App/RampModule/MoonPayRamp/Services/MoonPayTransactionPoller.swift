import Foundation
import MoonPay
import TKLogging

/// Asks MoonPay for a transaction's status until it settles. The payment frame reports `pending`
/// once the card is charged, and the final status only exists on MoonPay's side.
@MainActor
struct MoonPayTransactionPoller {
    /// Short intervals first, since a card payment usually settles within seconds.
    static let quickPollIntervals: [UInt64] = Array(repeating: 3_000_000_000, count: 5)
        + Array(repeating: 5_000_000_000, count: 9)
    /// After the quick ones the sheet says the payment is still processing, and polling slows down
    /// but goes on: delivering the crypto can take minutes. It ends when the sheet closes.
    static let slowPollInterval: UInt64 = 15_000_000_000
    /// How long slow polls go on, by the clock: time the app spends suspended counts too, so a
    /// sheet left open does not poll for ever.
    static let slowPollDuration: TimeInterval = 30 * 60

    /// Answers polling stops on. `fetch` retries a 401 once with a fresh connect, so one that
    /// arrives here is final.
    static let finalStatuses: Set<Int> = [400, 401, 403, 404]

    /// Connection states a silent connect cannot get past; polling stops on them.
    static let finalConnectionStatuses: Set<MoonPayConnectionStatus> = [
        .failed, .unavailable, .connectionRequired, .termsAcceptanceRequired,
    ]
    /// Added to the slow interval after a failed silent connect, so it runs at most once a minute.
    static let failedConnectBackoff: UInt64 = 45_000_000_000

    private static func isConnectFailure(_ error: Error) -> Bool {
        switch error as? MoonPayRampError {
        case .verificationFailed, .frame: true
        default: false
        }
    }

    /// Fetches the transaction, connecting to MoonPay first when the token expired. Without
    /// `allowsSignIn` that connect is silent and throws `signInRequired` instead of asking.
    var fetch: (_ id: String, _ allowsSignIn: Bool) async throws -> MoonPayTransactionDetails
    var sleep: (UInt64) async -> Void = { try? await Task.sleep(nanoseconds: $0) }
    var now: () -> Date = Date.init

    func poll(
        transaction: MoonPayTransaction,
        id: String,
        continuation: AsyncStream<MoonPayPaymentUpdate>.Continuation
    ) async {
        var attempt = 0
        var slowDeadline: Date?
        polling: while true {
            let isSlow = attempt >= Self.quickPollIntervals.count
            let interval: UInt64
            if isSlow {
                if slowDeadline == nil {
                    slowDeadline = now().addingTimeInterval(Self.slowPollDuration)
                    Log.multichainRamp.i("moonpay pay: transaction \(id) still processing, polling slower")
                    // Nobody reads the updates any more, so there is no one to poll for.
                    if case .terminated = continuation.yield(.stillProcessing(transaction)) { return }
                }
                guard let slowDeadline, now() < slowDeadline else { break polling }
                interval = Self.slowPollInterval
            } else {
                interval = Self.quickPollIntervals[attempt]
            }
            attempt += 1
            await sleep(interval)
            guard !Task.isCancelled else { return }
            do {
                // Late in the wait MoonPay's sign-in over the sheet is not worth it: slow polls
                // reconnect only silently, as Android does.
                let details = try await fetch(id, !isSlow)
                Log.multichainRamp.i("moonpay pay: transaction \(details.id) is \(details.status)")
                if let methodType = details.paymentMethodType,
                   case .terminated = continuation.yield(.paidWith(methodType: methodType))
                {
                    return
                }
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
            } catch MoonPayRampError.signInRequired {
                Log.multichainRamp.w("moonpay pay: sign-in required, transaction polling stops", extraInfo: ["id": id])
                break polling
            } catch let MoonPayRampError.verificationFailed(status) where isSlow && Self.finalConnectionStatuses.contains(status) {
                Log.multichainRamp.w("moonpay pay: connection is \(status), transaction polling stops", extraInfo: ["id": id])
                break polling
            } catch where isSlow && Self.isConnectFailure(error) {
                // A failed silent connect caches nothing, so the next poll reruns the whole
                // headless connect; a pending connection or a frame timeout may still clear, so
                // wait longer rather than stop.
                Log.multichainRamp.w("moonpay pay: silent connect failed, polling backs off", error: error)
                // No longer than the window has left, so the sheet does not wait past the deadline.
                let left = max(0, (slowDeadline ?? now()).timeIntervalSince(now()))
                await sleep(min(Self.failedConnectBackoff, UInt64(left * 1_000_000_000)))
                guard !Task.isCancelled else { return }
            } catch MoonPayRampError.verificationCancelled where !isSlow {
                // The user closed MoonPay's sign-in; asking again on every poll would nag. Slow
                // polls never present it, so a cancel there came from another flow's connect they
                // joined, and they keep going.
                Log.multichainRamp.w("moonpay pay: sign-in closed, transaction polling stops", extraInfo: ["id": id])
                break polling
            } catch let MoonPayAPIError.http(status, _) where Self.finalStatuses.contains(status) {
                // A bad request, a token refused after a fresh connect, or a missing transaction
                // does not get better with retries. A 408 or 425 does, so those go on.
                Log.multichainRamp.w("moonpay pay: transaction poll refused with \(status), polling stops", extraInfo: ["id": id])
                break polling
            } catch {
                Log.multichainRamp.w("moonpay pay: transaction poll failed", error: error)
            }
        }
        Log.multichainRamp.w("moonpay pay: transaction polling gave up", extraInfo: ["id": id])
        // The sheet stops promising progress that will not be reported.
        continuation.yield(.outcomeUnknown)
        continuation.finish()
    }
}
