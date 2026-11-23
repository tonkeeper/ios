import Foundation
import KeeperCore

enum MultichainTransactionID {
    /// `<chain>:<hash>` in lower case, as history files a transaction; a hash without a chain prefix
    /// takes `chain`.
    static func normalized(_ raw: String, chain: MultichainChain?) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let separator = value.firstIndex(of: ":"),
           let prefix = MultichainChain(assetIdChain: String(value[..<separator]))
        {
            return prefix.rawValue + value[separator...]
        }
        return "\(chain?.rawValue ?? "multichain"):\(value)"
    }
}
