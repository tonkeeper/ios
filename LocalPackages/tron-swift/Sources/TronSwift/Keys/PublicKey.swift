import Foundation
import secp256k1

public struct PublicKey: Key, Codable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    public static func publicKey(_ secp256k1PublicKey: secp256k1_pubkey, compressed: Bool) -> PublicKey {
        var outputLen: Int = compressed ? 33 : 65
        let context = secp256k1.Context.rawRepresentation
        var publicKey = secp256k1PublicKey
        var output = Data(count: outputLen)
        let compressedFlags = compressed ? UInt32(SECP256K1_EC_COMPRESSED) : UInt32(SECP256K1_EC_UNCOMPRESSED)
        output.withUnsafeMutableBytes { pointer in
            guard let p = pointer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }
            secp256k1_ec_pubkey_serialize(context, p, &outputLen, &publicKey, compressedFlags)
        }
        return PublicKey(data: output)
    }
}
