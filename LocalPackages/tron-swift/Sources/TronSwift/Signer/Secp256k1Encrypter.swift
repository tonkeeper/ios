import Foundation
import secp256k1

struct Secp256k1Encrypter {
    private let context: OpaquePointer

    init() {
        context = secp256k1.Context.rawRepresentation
    }

    func sign(hash: Data, privateKey: Data) -> secp256k1_ecdsa_recoverable_signature? {
        precondition(hash.count == 32, "Hash must be 32 bytes size")
        precondition(privateKey.count == 32, "PrivateKey must be 32 bytes size")
        var signature = secp256k1_ecdsa_recoverable_signature()

        let status = privateKey.withUnsafeBytes { key -> Int32 in
            hash.withUnsafeBytes { hash -> Int32 in
                secp256k1_ecdsa_sign_recoverable(context, &signature, hash.baseAddress!.assumingMemoryBound(to: UInt8.self), key.baseAddress!.assumingMemoryBound(to: UInt8.self), nil, nil)
            }
        }
        return status == 1 ? signature : nil
    }

    func export(signature: inout secp256k1_ecdsa_recoverable_signature) -> Data {
        var output = Data(count: 65)
        var recid = 0 as Int32
        _ = output.withUnsafeMutableBytes { output in
            secp256k1_ecdsa_recoverable_signature_serialize_compact(context, output.baseAddress!.assumingMemoryBound(to: UInt8.self), &recid, &signature)
        }

        // according TRON signature encoding spec: https://github.com/tronprotocol/tips/issues/120
        let v = UInt8(recid) + 27
        output[64] = v

        return output
    }
}
