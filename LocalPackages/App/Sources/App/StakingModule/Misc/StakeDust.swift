import BigInt

/// A stake up to 0.0000001 of the token is dust: Unstake stays off. Android uses the same threshold.
func isStakeDust(amount: BigUInt, fractionDigits: Int) -> Bool {
    amount * BigUInt(10).power(7) <= BigUInt(10).power(fractionDigits)
}
