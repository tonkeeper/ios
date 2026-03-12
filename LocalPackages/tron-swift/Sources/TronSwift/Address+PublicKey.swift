import CryptoSwift
import Foundation

public extension Address {
    init(publicKey: PublicKey) throws {
        let data = Data(publicKey.data.dropFirst())
        try self.init(raw: [0x41] + data.sha3(.keccak256).suffix(20))
    }
}
