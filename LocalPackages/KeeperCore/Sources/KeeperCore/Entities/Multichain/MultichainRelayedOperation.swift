import ChainKit
import Foundation
import TKLogging

enum MultichainRelayedOperationError: Error, Equatable {
    case malformed(String)
    /// The operation carries a payload the wallet would pay for itself.
    case foreignPayload(id: String, type: String)
}

extension MultichainRelayedOperationError: LoggableError {
    var logDescription: String {
        switch self {
        case let .malformed(reason):
            return "type=MultichainRelayedOperationError, case=malformed, reason=\(reason)"
        case let .foreignPayload(id, type):
            return "type=MultichainRelayedOperationError, case=foreignPayload, id=\(id), payloadType=\(type)"
        }
    }
}

/// An operation a relayer built for the wallet to sign: only the documents the relayer submits on
/// its own transaction — an EIP-7702 authorization, an EIP-7821 Hermes delegate. A `main` payload
/// would come back as a transaction the wallet pays for, so it is refused here.
struct MultichainRelayedOperation {
    let id: String
    /// The envelope JSON as the relayer wrote it.
    let json: String
    let operation: ChainKit.Operation

    init(id: String, json: String) throws(MultichainRelayedOperationError) {
        let result = ChainKit.Operation.Companion.shared.parse(id: id, meta: json)
        guard let operation = result.getOrNull() else {
            throw .malformed(result.error?.message ?? "unknown")
        }
        for payload in operation.payloads where !Self.relayedTypes.contains(payload.type) {
            throw .foreignPayload(id: payload.id, type: payload.type.id)
        }
        self.id = id
        self.json = json
        self.operation = operation
    }

    var payloadIds: [String] {
        operation.payloads.map(\.id)
    }

    static let relayedTypes: [ChainKit.Payload.Type_] = [.eip7702authorization, .eip7821hermesdelegate]
}

/// Signs the documents of a relayed operation with the wallet's keys.
protocol MultichainRelayedOperationSigner {
    /// Signs every payload of `operation` with the wallet's `chain` key and returns the envelope
    /// the relayer broadcasts from, `{"operation": {"id": …, "payloads": [ … ]}}`, as JSON. The
    /// relayer pays the chain, so no fee or nonce of the sender's goes into the signatures.
    func signRelayedOperation(
        passcodeProvider: @escaping () async -> String?,
        wallet: Wallet,
        chain: MultichainChain,
        operation: MultichainRelayedOperation
    ) async throws(MultichainTransactionFailure) -> Data
}
