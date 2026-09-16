import Foundation
@preconcurrency import ReownWalletKit
import TKLogging

@WalletConnectActor
final class WalletConnectAutoRejectService: Sendable {
    private let network: any WalletConnectWalletKitClientProtocol
    private let retryDelays: [UInt64]
    private let maxAttempts: Int
    private var requestTasks = [WalletConnectAutoRejectRequestKey: WalletConnectAutoRejectTask]()

    init(
        network: any WalletConnectWalletKitClientProtocol,
        retryDelays: [UInt64] = [
            1_000_000_000,
            2_000_000_000,
            5_000_000_000,
            10_000_000_000,
            30_000_000_000,
        ],
        maxAttempts: Int = 6
    ) {
        self.network = network
        self.retryDelays = retryDelays
        self.maxAttempts = max(1, maxAttempts)
    }

    deinit {
        requestTasks.values.forEach { $0.task.cancel() }
    }

    func rejectRequest(
        topic: String,
        requestId: RPCID,
        context: String,
        error: JSONRPCError = .walletConnectUserRejected
    ) {
        let key = WalletConnectAutoRejectRequestKey(
            topic: topic,
            requestId: requestId.string
        )
        guard requestTasks[key] == nil else {
            logAutoRequestRejectionAlreadyScheduled(key: key, context: context)
            return
        }

        let taskId = UUID()
        let task = Task { [network, retryDelays, maxAttempts] in
            await runAutoRejectRequest(
                key: key,
                requestId: requestId,
                taskId: taskId,
                network: network,
                retryDelays: retryDelays,
                maxAttempts: maxAttempts,
                context: context,
                error: error,
                completion: { [weak self] in
                    await self?.finishRequest(key: key, taskId: taskId)
                }
            )
        }
        requestTasks[key] = WalletConnectAutoRejectTask(id: taskId, task: task)
    }

    func cancelRequest(
        topic: String,
        requestId: String,
        context: String
    ) {
        let key = WalletConnectAutoRejectRequestKey(
            topic: topic,
            requestId: requestId
        )
        guard let task = requestTasks.removeValue(forKey: key) else {
            return
        }
        task.task.cancel()
        logAutoRequestRejectionCancelled(key: key, context: context)
    }

    func cancelRequests(
        requestId: String,
        context: String
    ) {
        let keys = requestTasks.keys.filter { $0.requestId == requestId }
        for key in keys {
            cancelRequest(
                topic: key.topic,
                requestId: key.requestId,
                context: context
            )
        }
    }

    func cancelRequests(
        topic: String,
        context: String
    ) {
        let keys = requestTasks.keys.filter { $0.topic == topic }
        for key in keys {
            cancelRequest(
                topic: key.topic,
                requestId: key.requestId,
                context: context
            )
        }
    }
}

private extension WalletConnectAutoRejectService {
    func finishRequest(
        key: WalletConnectAutoRejectRequestKey,
        taskId: UUID
    ) {
        guard requestTasks[key]?.id == taskId else {
            return
        }
        requestTasks.removeValue(forKey: key)
    }
}

private func runAutoRejectRequest(
    key: WalletConnectAutoRejectRequestKey,
    requestId: RPCID,
    taskId _: UUID,
    network: any WalletConnectWalletKitClientProtocol,
    retryDelays: [UInt64],
    maxAttempts: Int,
    context: String,
    error: JSONRPCError,
    completion: @escaping @Sendable () async -> Void
) async {
    var attempt = 0
    var lastError: (any Error)?

    while !Task.isCancelled {
        let currentAttempt = attempt + 1
        do {
            try await network.rejectRequest(
                topic: key.topic,
                requestId: requestId,
                error: error
            )
            logAutoRequestRejectionCompleted(
                key: key,
                context: context,
                attempt: currentAttempt
            )
            await completion()
            return
        } catch {
            lastError = error
            logAutoRequestRejectionFailure(
                key: key,
                context: context,
                attempt: currentAttempt,
                error: error
            )
            guard error.isRetryableDeliveryFailure else {
                await completion()
                return
            }
        }

        attempt += 1
        guard attempt < maxAttempts else {
            logAutoRequestRejectionTerminalFailure(
                key: key,
                context: context,
                attempt: attempt,
                error: lastError ?? WalletConnectAutoRejectError.attemptsExhausted
            )
            await completion()
            return
        }

        do {
            try await Task.sleep(nanoseconds: autoRejectRetryDelay(
                attempt: attempt,
                retryDelays: retryDelays
            ))
        } catch {
            break
        }
    }

    await completion()
}

private func autoRejectRetryDelay(
    attempt: Int,
    retryDelays: [UInt64]
) -> UInt64 {
    guard !retryDelays.isEmpty else {
        return 0
    }
    return retryDelays[min(attempt - 1, retryDelays.count - 1)]
}

private func logAutoRequestRejectionAlreadyScheduled(
    key: WalletConnectAutoRejectRequestKey,
    context: String
) {
    Log.walletConnect.i("auto request rejection already scheduled", extraInfo: [
        "requestId": key.requestId,
        "context": context,
    ])
}

private func logAutoRequestRejectionCancelled(
    key: WalletConnectAutoRejectRequestKey,
    context: String
) {
    Log.walletConnect.i("auto request rejection cancelled", extraInfo: [
        "requestId": key.requestId,
        "context": context,
    ])
}

private func logAutoRequestRejectionCompleted(
    key: WalletConnectAutoRejectRequestKey,
    context: String,
    attempt: Int
) {
    Log.walletConnect.i("auto request rejection completed", extraInfo: [
        "requestId": key.requestId,
        "context": context,
        "attempt": "\(attempt)",
    ])
}

private func logAutoRequestRejectionFailure(
    key: WalletConnectAutoRejectRequestKey,
    context: String,
    attempt: Int,
    error: Error
) {
    Log.e(
        "WalletConnect: failed to auto-reject request after \(context)",
        error: error,
        extraInfo: [
            "requestId": key.requestId,
            "attempt": "\(attempt)",
        ]
    )
}

private func logAutoRequestRejectionTerminalFailure(
    key: WalletConnectAutoRejectRequestKey,
    context: String,
    attempt: Int,
    error: Error
) {
    Log.walletConnect.e(
        "auto request rejection attempts exhausted",
        error: error,
        extraInfo: [
            "requestId": key.requestId,
            "context": context,
            "attempt": "\(attempt)",
        ]
    )
}

private enum WalletConnectAutoRejectError: LoggableError {
    case attemptsExhausted

    var logDescription: String {
        "type=WalletConnectAutoRejectError, case=attemptsExhausted"
    }
}

private struct WalletConnectAutoRejectRequestKey: Hashable {
    let topic: String
    let requestId: String
}

private struct WalletConnectAutoRejectTask {
    let id: UUID
    let task: Task<Void, Never>
}
