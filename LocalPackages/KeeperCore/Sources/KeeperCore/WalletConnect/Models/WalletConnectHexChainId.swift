@preconcurrency import BigInt
import Foundation

extension String {
    var walletConnectCanonicalHexChainId: String? {
        let normalized = lowercased()
        guard normalized.hasPrefix("0x"), normalized.count > 2,
              let value = BigUInt(String(normalized.dropFirst(2)), radix: 16)
        else {
            return nil
        }
        return "0x\(String(value, radix: 16))"
    }
}
