import Foundation

public extension Data {
    /// Named apart from the `Data(hex:)` overloads shipped by `TonSwift` and `WalletConnectUtils`:
    /// both decode a malformed string into plausible-looking bytes instead of failing, and which one
    /// wins is decided by overload resolution at the call site.
    ///
    /// `KeeperCoreComponents` carries an identical copy for the modules that cannot reach this one;
    /// see the note there. `DataHexTests` runs the same vectors as its `DataStrictHexTests`.
    init?(strictHex hex: String) {
        var hex = hex
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }

        guard hex.count.isMultiple(of: 2) else {
            return nil
        }

        let len = hex.count / 2
        var data = Data(capacity: len)
        var i = hex.startIndex

        for _ in 0 ..< len {
            let j = hex.index(i, offsetBy: 2)
            let bytes = hex[i ..< j]

            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }

            i = j
        }
        self = data
    }
}

extension Data {
    func hexString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
