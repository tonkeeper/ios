import BigInt
import Foundation

struct WalletGetAccountResponse: Decodable {
    let balance: DirtyBigInt?
    let address: String?
    let createTime: Int64?

    enum CodingKeys: String, CodingKey {
        case balance
        case address
        case createTime = "create_time"
    }

    /// TronGrid returns `{}` for never-activated accounts. Activated accounts include at least
    /// `address` / `create_time`, and often an explicit `balance` (including zero).
    var exists: Bool {
        if let address, !address.isEmpty {
            return true
        }
        if createTime != nil {
            return true
        }
        return balance != nil
    }
}
