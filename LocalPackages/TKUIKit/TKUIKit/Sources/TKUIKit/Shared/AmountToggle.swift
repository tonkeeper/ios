/// The amount as it was written before the last token ↔ fiat toggle. Each conversion rounds,
/// so re-deriving the amount on every toggle shrinks it a little each pass; toggling straight
/// back restores the captured one instead. The owner resets it on every other change to the
/// amount or to what the amount converts against.
public struct AmountToggle<Value: Equatable>: Equatable {
    public private(set) var counterpart: Value?

    public init() {}

    /// What to show after the toggle: the value captured at the previous toggle, else `converted`.
    public mutating func toggle(_ current: Value, converted: Value) -> Value {
        let next = counterpart ?? converted
        counterpart = current
        return next
    }

    public mutating func reset() {
        counterpart = nil
    }
}
