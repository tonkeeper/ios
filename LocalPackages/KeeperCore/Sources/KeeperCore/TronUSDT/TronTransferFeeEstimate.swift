import BigInt

/// The two bandwidth pools of a TRON account. They are never merged: the node offers the whole
/// transaction to `staked` first, then to `free`, and burns TRX when neither covers it alone.
public struct TronBandwidthAllowance: Equatable, Sendable {
    public let staked: Int
    public let free: Int

    public init(staked: Int, free: Int) {
        self.staked = max(staked, 0)
        self.free = max(free, 0)
    }
}

public struct TronTransferFeeEstimate {
    /// Energy the battery relay should sponsor. Independent of the self-paid TRX burn.
    public let energy: Int
    /// Bandwidth the battery relay should sponsor (transaction size with margin), not the
    /// leftover burn after free/staked pools. Those pools only affect `requiredTRXSun`.
    public let bandwidth: Int
    /// What the pools hold once this transfer has taken its share, for a leg that follows it from the
    /// same account. A burned transfer leaves both pools untouched. Models the ordinary per-byte
    /// charge only: a transfer that creates the destination account pays out of a different budget,
    /// and it is always the last leg of a migration.
    public let remainingBandwidth: TronBandwidthAllowance
    public let requiredBatteryCharges: Int
    public let requiredTRXSun: BigUInt
    /// Protocol burn owed by the sender when this transfer has to create the destination account.
    /// Kept apart from `requiredTRXSun` because no fee payer can sponsor it.
    public let destinationActivationSun: BigUInt
    public let requiredTONAmountNano: BigUInt?
    public let tonFeeAddress: String?

    /// The whole cost the sender owes in TRX. Creating the destination account replaces this
    /// transfer's per-byte charge, so the two are alternatives rather than a sum.
    public var selfPaidTRXSun: BigUInt {
        destinationActivationSun > 0 ? destinationActivationSun : requiredTRXSun
    }

    /// Account creation burns from the sender, which neither the battery relay nor a GRAM instant
    /// fee can cover, so TRX is the only way such a transfer can be paid for.
    public var requiresSelfPaidTRX: Bool {
        destinationActivationSun > 0
    }

    public init(
        energy: Int,
        bandwidth: Int,
        remainingBandwidth: TronBandwidthAllowance = TronBandwidthAllowance(staked: 0, free: 0),
        requiredBatteryCharges: Int,
        requiredTRXSun: BigUInt,
        destinationActivationSun: BigUInt = 0,
        requiredTONAmountNano: BigUInt?,
        tonFeeAddress: String?
    ) {
        self.energy = energy
        self.bandwidth = bandwidth
        self.remainingBandwidth = remainingBandwidth
        self.requiredBatteryCharges = requiredBatteryCharges
        self.requiredTRXSun = requiredTRXSun
        self.destinationActivationSun = destinationActivationSun
        self.requiredTONAmountNano = requiredTONAmountNano
        self.tonFeeAddress = tonFeeAddress
    }
}
