import BigInt

public extension AmountFormatter {
    /// Formats two amounts of the same token so that different values never render as the same string:
    /// falls back to `.exactValue` when the configured style rounds them together.
    func formatDistinctly(
        _ first: BigUInt,
        _ second: BigUInt,
        fractionDigits: Int,
        accessory: AmountAccessoryType = .none
    ) -> (String, String) {
        let formatted = (
            format(amount: first, fractionDigits: fractionDigits, accessory: accessory),
            format(amount: second, fractionDigits: fractionDigits, accessory: accessory)
        )
        guard first != second, formatted.0 == formatted.1 else {
            return formatted
        }
        return (
            format(amount: first, fractionDigits: fractionDigits, accessory: accessory, style: .exactValue),
            format(amount: second, fractionDigits: fractionDigits, accessory: accessory, style: .exactValue)
        )
    }
}
