/// A chain family with no relayable form of its main payload simply has no case here.
enum MultichainSwapBatteryPayload: Sendable, Hashable {
    case ton(TonSwapMessage)
    case tonJettonDeposit(TonJettonSwapDeposit)
    case tron(TronSwapTransfer)
}

extension MultichainSwapBatteryPayload {
    var chain: MultichainChain {
        switch self {
        case .ton, .tonJettonDeposit:
            return .ton
        case .tron:
            return .tron
        }
    }
}
