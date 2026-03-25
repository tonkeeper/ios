import BigInt

public struct TronTransferFeeEstimate {
    public let energy: Int
    public let bandwidth: Int
    public let requiredBatteryCharges: Int
    public let requiredTRXSun: BigUInt
    public let requiredTONAmountNano: BigUInt?
    public let tonFeeAddress: String?

    public init(
        energy: Int,
        bandwidth: Int,
        requiredBatteryCharges: Int,
        requiredTRXSun: BigUInt,
        requiredTONAmountNano: BigUInt?,
        tonFeeAddress: String?
    ) {
        self.energy = energy
        self.bandwidth = bandwidth
        self.requiredBatteryCharges = requiredBatteryCharges
        self.requiredTRXSun = requiredTRXSun
        self.requiredTONAmountNano = requiredTONAmountNano
        self.tonFeeAddress = tonFeeAddress
    }
}
