@preconcurrency import BigInt

/// What the user agreed to: built from their own input, never read off the operation it is held to.
struct OperationIntent: Sendable, Equatable {
    struct Spend: Sendable, Equatable {
        let assetId: String
        /// How a finding names the asset, and nothing more: no check holds an operation to it, so the
        /// review id leaves it out.
        let symbol: String
        let decimals: Int
        /// In the asset's smallest units.
        let amount: BigUInt
    }

    /// `nil` only for a dApp's request: ChainKit fails fatally on a wallet intent without spends.
    let spends: [Spend]?
    /// The most a relayer paid in a token takes besides the spends. Kept apart from them: chain-kit
    /// holds a fee the relayer's payload states to that quote itself, so this one counts only where
    /// no payload states one.
    let relayerFee: Spend?
    let recipient: String?
    let isDapp: Bool

    private init(spends: [Spend]?, relayerFee: Spend?, recipient: String?, isDapp: Bool) {
        self.spends = spends
        self.relayerFee = relayerFee
        self.recipient = recipient
        self.isDapp = isDapp
    }

    static func wallet(spending spends: [Spend], relayerFee: Spend? = nil, to recipient: String?) -> OperationIntent {
        OperationIntent(spends: spends, relayerFee: relayerFee, recipient: recipient, isDapp: false)
    }

    static let dapp = OperationIntent(spends: nil, relayerFee: nil, recipient: nil, isDapp: true)
}
