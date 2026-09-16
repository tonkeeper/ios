import Foundation

public extension Data {
    /// Deliberately not spelled `Data(hex:)`. Three overloads of that name reach this module —
    /// `TonSwift` truncates an odd-length string to the last whole byte pair, `WalletConnectUtils`
    /// is non-failable and turns anything malformed into empty or padded bytes — and which one wins
    /// is decided by overload resolution at the call site, not by the author. Both failure modes
    /// produce plausible-looking bytes, so a wrong key, payload or signature travels on unnoticed.
    ///
    /// `TronSwiftAPI` carries an identical copy for the TronSwift package, which cannot reach this
    /// module and does not warrant a shared one for twenty lines. The duplication is safe in a way
    /// `Data(hex:)` was not: the two signatures are the same, so a call site that ever saw both
    /// would fail to compile as ambiguous rather than silently pick one. What has to hold is that
    /// they behave alike, which `DataStrictHexTests` and `DataHexTests` pin with the same vectors.
    init?(strictHex hex: String) {
        let hex = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard hex.count.isMultiple(of: 2) else {
            return nil
        }

        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< next], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = next
        }
        self = data
    }
}
