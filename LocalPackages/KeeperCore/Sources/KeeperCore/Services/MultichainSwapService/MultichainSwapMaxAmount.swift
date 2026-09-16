import BigInt

public enum MultichainSwapMaxAmount {
    public static func maxSwapInputAmount(for asset: MultichainAsset) -> BigUInt {
        guard asset.asset.isNative, asset.asset.chain == .ton else {
            return asset.balance
        }
        let reserve = NativeSwapConstants.tonFeeReserve
        guard asset.balance > reserve else {
            return 0
        }
        return asset.balance - reserve
    }

    public static func tonMaxUnavailableDueToFeeReserve(for asset: MultichainAsset) -> Bool {
        guard asset.asset.isNative, asset.asset.chain == .ton, asset.balance > 0 else {
            return false
        }
        return asset.balance <= NativeSwapConstants.tonFeeReserve
    }
}
