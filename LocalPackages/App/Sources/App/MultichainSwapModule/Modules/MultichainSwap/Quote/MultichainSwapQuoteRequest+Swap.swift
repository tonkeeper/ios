import KeeperCore

extension MultichainSwapQuoteRequest {
    static let exactInputType = "exact_input"

    /// A deposit address turns the swap into a plain transfer, which cannot carry the message an
    /// on-chain TON swap needs, so a TON source asks for the full signing payload instead.
    static func returnDepositAddress(sourceChain: MultichainChain) -> Bool {
        sourceChain != .ton
    }
}
