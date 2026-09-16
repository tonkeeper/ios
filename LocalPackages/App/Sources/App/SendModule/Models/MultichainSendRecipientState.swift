import KeeperCore

enum MultichainSendRecipientState {
    enum FailureReason: Equatable {
        case invalidAddress
        case scam
    }

    enum Validation: Equatable {
        case empty
        case resolving
        case valid
        case chainMismatch
        case invalidAddress
        case scam
        case selfSendForbidden
    }

    case empty
    case resolved(input: String, recipient: MultichainRecipient, isMemoRequired: Bool)
    case resolving(input: String, generation: UInt64, task: Task<Void, Never>)
    case failed(input: String, reason: FailureReason)

    var input: String {
        switch self {
        case .empty:
            return ""
        case let .resolved(input, _, _), let .resolving(input, _, _), let .failed(input, _):
            return input
        }
    }

    var recipient: MultichainRecipient? {
        guard case let .resolved(_, recipient, _) = self else { return nil }
        return recipient
    }

    var isMemoRequired: Bool {
        guard case let .resolved(_, _, isMemoRequired) = self else { return false }
        return isMemoRequired
    }

    func validation(
        expectedChain: MultichainChain?,
        forbiddenSelfSendAddress: String? = nil
    ) -> Validation {
        switch self {
        case .empty:
            return .empty
        case .resolving:
            return .resolving
        case let .resolved(_, recipient, _):
            guard recipient.chain == expectedChain else {
                return .chainMismatch
            }
            if let forbiddenSelfSendAddress, recipient.address == forbiddenSelfSendAddress {
                return .selfSendForbidden
            }
            return .valid
        case let .failed(_, reason):
            switch reason {
            case .invalidAddress:
                return .invalidAddress
            case .scam:
                return .scam
            }
        }
    }

    static func resolutionResult(input: String, resolved: LegacyRecipient?) -> MultichainSendRecipientState {
        guard case let .ton(tonRecipient) = resolved else {
            return .failed(input: input, reason: .invalidAddress)
        }
        guard !tonRecipient.isScam else {
            return .failed(input: input, reason: .scam)
        }
        return .resolved(
            input: input,
            recipient: MultichainRecipient(
                chain: .ton,
                address: tonRecipient.recipientAddress.addressString,
                domain: tonRecipient.recipientAddress.name
            ),
            isMemoRequired: tonRecipient.isMemoRequired
        )
    }
}
