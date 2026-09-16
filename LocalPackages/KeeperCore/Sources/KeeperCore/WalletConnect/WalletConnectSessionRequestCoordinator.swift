import Foundation
@preconcurrency import ReownWalletKit
import TKLogging

@WalletConnectActor
final class WalletConnectSessionRequestCoordinator: Sendable {
    private let network: WalletConnectWalletKitClientProtocol
    private let parser: WalletConnectMethodParser

    private var pendingRequests = [WalletConnectPendingRequestKey: Request]()
    private var receivedRequestKeys = Set<WalletConnectPendingRequestKey>()

    init(
        network: WalletConnectWalletKitClientProtocol,
        parser: WalletConnectMethodParser = WalletConnectMethodParser()
    ) {
        self.network = network
        self.parser = parser
    }
}

extension WalletConnectSessionRequestCoordinator {
    func receive(
        _ request: Request,
        sessionContext: WalletConnectSessionContextLookup
    ) -> WalletConnectSessionRequestReceiveResult {
        let key = WalletConnectPendingRequestKey(
            topic: request.topic,
            requestId: request.id.string
        )
        guard receivedRequestKeys.insert(key).inserted else {
            logDuplicateSessionRequestIgnored(request)
            return .duplicate
        }
        pendingRequests[key] = request

        guard case let .found(context) = sessionContext else {
            pendingRequests.removeValue(forKey: key)
            let action = autoRejectAction(
                request: request,
                context: autoRejectContext(for: sessionContext),
                message: requestErrorMessage(for: sessionContext)
            )
            switch sessionContext {
            case .missingDapp:
                return .missingDapp(action)
            case .missingWalletMapping:
                return .missingWalletMapping(action)
            case .found:
                return .requestError(action)
            }
        }

        do {
            let parsed = try parser.parse(
                method: request.method,
                chain: request.chainId.absoluteString,
                paramsJSON: request.params.stringRepresentation
            )
            logSessionRequestReceived(request, dapp: context.dapp)
            return .sessionRequest(
                WalletConnectSessionRequest(
                    id: request.id.string,
                    topic: request.topic,
                    chain: parsed.chain,
                    method: parsed.method,
                    dapp: context.dapp,
                    payload: parsed.payload,
                    source: context.sourceState.extraInfo?.source,
                    walletId: context.walletId
                )
            )
        } catch {
            pendingRequests.removeValue(forKey: key)
            Log.walletConnect.w(
                "request parsing failed",
                error: error,
                extraInfo: requestLogInfo(request)
            )
            return .requestError(
                autoRejectAction(
                    request: request,
                    context: "request parsing failed with \(error.logDescription)",
                    message: "\(error)",
                    error: jsonRPCError(for: error, request: request)
                )
            )
        }
    }

    func approve(
        id: String,
        topic: String,
        result: WalletConnectResponseValue
    ) async throws(WalletConnectResponseError) {
        let request = try pendingRequest(id: id, topic: topic)
        do {
            try await network.approveRequest(
                topic: request.topic,
                requestId: request.id,
                result: result
            )
            clearRequest(key: request.key)
        } catch {
            if !error.isRetryableDeliveryFailure {
                clearRequest(key: request.key)
            }
            Log.walletConnect.w(
                "request approval delivery failed",
                error: error,
                extraInfo: requestLogInfo(request)
            )
            throw error
        }
    }

    func reject(
        id: String,
        topic: String,
        reason: WalletConnectRequestRejectionReason
    ) async throws(WalletConnectResponseError) {
        try await reject(
            id: id,
            topic: topic,
            error: jsonRPCError(for: reason)
        )
    }

    func reject(
        id: String,
        topic: String,
        error: JSONRPCError
    ) async throws(WalletConnectResponseError) {
        let request = try pendingRequest(id: id, topic: topic)
        do {
            try await network.rejectRequest(
                topic: request.topic,
                requestId: request.id,
                error: error
            )
            clearRequest(key: request.key)
        } catch {
            if !error.isRetryableDeliveryFailure {
                clearRequest(key: request.key)
            }
            Log.walletConnect.w(
                "request rejection delivery failed",
                error: error,
                extraInfo: requestLogInfo(request)
            )
            throw error
        }
    }

    func expire(requestId: String) -> [WalletConnectExpiredSessionRequest] {
        let expiredKeys = pendingRequests.keys.filter { $0.requestId == requestId }
        for key in expiredKeys {
            clearRequest(key: key)
            logSessionRequestExpired(key)
        }
        return expiredKeys.map {
            WalletConnectExpiredSessionRequest(
                topic: $0.topic,
                requestId: $0.requestId
            )
        }
    }

    func removePendingRequests(topic: String) {
        pendingRequests = pendingRequests.filter { $0.key.topic != topic }
        receivedRequestKeys = receivedRequestKeys.filter { $0.topic != topic }
    }
}

private extension WalletConnectSessionRequestCoordinator {
    func clearRequest(key: WalletConnectPendingRequestKey) {
        pendingRequests.removeValue(forKey: key)
        receivedRequestKeys.remove(key)
    }

    func pendingRequest(
        id: String,
        topic: String
    ) throws(WalletConnectResponseError) -> WalletConnectPendingRequest {
        let key = WalletConnectPendingRequestKey(
            topic: topic,
            requestId: id
        )
        guard let request = pendingRequests[key] else {
            let error = WalletConnectResponseError.missingRequest(id: id)
            Log.walletConnect.w(
                "request response failed: pending request missing",
                error: error,
                extraInfo: [
                    "requestId": id,
                ]
            )
            throw error
        }
        return WalletConnectPendingRequest(
            key: key,
            topic: request.topic,
            id: request.id
        )
    }

    func autoRejectAction(
        request: Request,
        context: String,
        message: String,
        error: JSONRPCError = .walletConnectUserRejected
    ) -> WalletConnectSessionRequestAutoReject {
        WalletConnectSessionRequestAutoReject(
            topic: request.topic,
            requestId: request.id,
            context: context,
            error: error,
            errorEvent: WalletConnectErrorEvent(
                topic: request.topic,
                message: message
            )
        )
    }

    func autoRejectContext(
        for lookup: WalletConnectSessionContextLookup
    ) -> String {
        switch lookup {
        case .found:
            return "request session context resolved"
        case .missingDapp:
            return "missing dApp metadata"
        case .missingWalletMapping:
            return "missing wallet mapping"
        }
    }

    func requestErrorMessage(
        for lookup: WalletConnectSessionContextLookup
    ) -> String {
        switch lookup {
        case .found:
            return "WalletConnect request session context is available"
        case .missingDapp:
            return "WalletConnect request has no dApp metadata"
        case .missingWalletMapping:
            return "WalletConnect request has no wallet mapping"
        }
    }

    func jsonRPCError(for error: Error, request: Request) -> JSONRPCError {
        guard let parsingError = error as? WalletConnectRequestParsingError else {
            return .walletConnectUserRejected
        }
        switch parsingError {
        case .invalidParams,
             .chainMismatch:
            return .walletConnectInvalidParams
        case .unsupportedChain:
            return .walletConnectUnsupportedChain
        case let .unsupportedMethod(method):
            if method == "wallet_sendCalls",
               request.params.stringRepresentation.walletSendCallsAtomicRequired == true
            {
                return .walletConnectAtomicityNotSupported
            }
            return .methodNotFound
        }
    }

    func jsonRPCError(for reason: WalletConnectRequestRejectionReason) -> JSONRPCError {
        switch reason {
        case .userRejected:
            return .walletConnectUserRejected
        case .invalidParams:
            return .walletConnectInvalidParams
        case .unsupportedChain:
            return .walletConnectUnsupportedChain
        case .notImplemented:
            return .walletConnectNotImplemented
        }
    }
}

private extension String {
    var walletSendCallsAtomicRequired: Bool? {
        guard let data = data(using: .utf8) else {
            return nil
        }
        return (try? JSONDecoder().decode(WalletConnectSendCallsParams.self, from: data))?.atomicRequired
            ?? (try? JSONDecoder().decode([WalletConnectSendCallsParams].self, from: data))?.first?.atomicRequired
    }
}

private struct WalletConnectSendCallsParams: Decodable {
    let atomicRequired: Bool?
}

enum WalletConnectSessionRequestReceiveResult {
    case sessionRequest(WalletConnectSessionRequest)
    case missingDapp(WalletConnectSessionRequestAutoReject)
    case missingWalletMapping(WalletConnectSessionRequestAutoReject)
    case requestError(WalletConnectSessionRequestAutoReject)
    case duplicate
}

struct WalletConnectSessionRequestAutoReject {
    let topic: String
    let requestId: RPCID
    let context: String
    let error: JSONRPCError
    let errorEvent: WalletConnectErrorEvent
}

struct WalletConnectExpiredSessionRequest: Equatable {
    let topic: String
    let requestId: String
}

private struct WalletConnectPendingRequestKey: Hashable {
    let topic: String
    let requestId: String
}

private struct WalletConnectPendingRequest {
    let key: WalletConnectPendingRequestKey
    let topic: String
    let id: RPCID
}

private func logSessionRequestReceived(
    _ request: Request,
    dapp: WalletConnectDapp
) {
    Log.walletConnect.i("request received", extraInfo: [
        "requestId": request.id.string,
        "method": request.method,
        "chainId": request.chainId.absoluteString,
        "paramsLength": "\(request.params.stringRepresentation.count)",
    ])
}

private func requestLogInfo(_ request: Request) -> [String: String] {
    [
        "requestId": request.id.string,
        "method": request.method,
        "chainId": request.chainId.absoluteString,
    ]
}

private func requestLogInfo(_ request: WalletConnectPendingRequest) -> [String: String] {
    [
        "requestId": request.id.string,
    ]
}

private func logSessionRequestExpired(_ key: WalletConnectPendingRequestKey) {
    Log.walletConnect.i("request expired", extraInfo: [
        "requestId": key.requestId,
    ])
}

private func logDuplicateSessionRequestIgnored(_ request: Request) {
    Log.walletConnect.i("duplicate request ignored", extraInfo: [
        "requestId": request.id.string,
        "method": request.method,
        "chainId": request.chainId.absoluteString,
    ])
}
