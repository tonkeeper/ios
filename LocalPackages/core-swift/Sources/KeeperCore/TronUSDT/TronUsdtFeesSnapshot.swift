import BigInt
import Foundation

public struct TronUsdtFeesSnapshot {
    public let isTRXOnlyRegion: Bool

    public let requiredTRX: BigUInt
    public let trxBalance: BigUInt

    public let requiredBatteryCharges: Int
    public let batteryChargesBalance: Int
    public let batteryFillPercent: CGFloat

    public let requiredTON: BigUInt
    public let tonBalance: BigUInt

    public init(
        isTRXOnlyRegion: Bool,
        requiredTRX: BigUInt,
        trxBalance: BigUInt,
        requiredBatteryCharges: Int,
        batteryChargesBalance: Int,
        batteryFillPercent: CGFloat,
        requiredTON: BigUInt,
        tonBalance: BigUInt
    ) {
        self.isTRXOnlyRegion = isTRXOnlyRegion
        self.requiredTRX = requiredTRX
        self.trxBalance = trxBalance
        self.requiredBatteryCharges = requiredBatteryCharges
        self.batteryChargesBalance = batteryChargesBalance
        self.batteryFillPercent = batteryFillPercent
        self.requiredTON = requiredTON
        self.tonBalance = tonBalance
    }

    public var trxTransfersAvailable: Int {
        guard requiredTRX > 0 else { return 0 }
        return Int(trxBalance / BigUInt(requiredTRX))
    }

    public var batteryTransfersAvailable: Int {
        guard requiredBatteryCharges > 0 else { return 0 }
        return batteryChargesBalance / requiredBatteryCharges
    }

    public var tonTransfersAvailable: Int {
        guard requiredTON > 0 else { return 0 }
        return Int(tonBalance / requiredTON)
    }

    public var totalTransfersAvailable: Int {
        if isTRXOnlyRegion {
            return trxTransfersAvailable
        }

        return trxTransfersAvailable + batteryTransfersAvailable + tonTransfersAvailable
    }

    public var hasEnoughForAtLeastOneTransfer: Bool {
        totalTransfersAvailable > 0
    }
}
