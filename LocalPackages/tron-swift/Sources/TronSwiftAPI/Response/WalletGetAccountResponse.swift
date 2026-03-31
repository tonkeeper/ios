import BigInt
import Foundation

struct WalletGetAccountResponse: Decodable {
    let balance: DirtyBigInt?
}
