@preconcurrency import BigInt

/// The single TON message a swap payload boils down to, with no ChainKit types attached.
struct TonSwapMessage: Sendable, Hashable {
    let to: String
    let amount: BigUInt
    let payload: String?
    let stateInit: String?
}

/// A deposit-style TON swap that must be rebuilt as a jetton transfer rather than a raw TON send.
struct TonJettonSwapDeposit: Sendable, Hashable {
    let recipient: String
    let amount: BigUInt
}
