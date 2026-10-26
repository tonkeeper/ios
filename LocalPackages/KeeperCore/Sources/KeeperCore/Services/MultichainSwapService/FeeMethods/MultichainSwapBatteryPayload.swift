/// A chain family with no relayable form of its main payload simply has no case here.
enum MultichainSwapBatteryPayload: Sendable, Hashable {
    case ton([TonSwapMessage])
    case tonJettonDeposit(TonJettonSwapDeposit)
    case tron(TronSwapTransfer)
    case evm(EVMSwapRelay)
}

extension MultichainSwapBatteryPayload {
    var chain: MultichainChain {
        switch self {
        case .ton, .tonJettonDeposit:
            return .ton
        case .tron:
            return .tron
        case let .evm(relay):
            return relay.chain
        }
    }
}

/// What the relayer is asked to carry for an EVM swap: the route's one call.
struct EVMSwapRelay: Sendable, Hashable {
    let chain: MultichainChain
    let call: EVMGaslessCall
}
