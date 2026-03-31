import Foundation
import secp256k1

public struct Secp256k1DerivationCurve: DerivationCurve {
    enum Error: Swift.Error {
        case tweakFailed
    }

    public init() {}

    public var seedSalt: String {
        "Bitcoin seed"
    }

    public var supportNonHardened: Bool {
        true
    }

    public func derivedPrivateKey(parentPrivateKey: Data, childKey: Data) throws -> Data {
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!
        defer {
            secp256k1_context_destroy(context)
        }

        var rawVariable = parentPrivateKey
        if rawVariable.withUnsafeMutableBytes({ privateKeyBytes -> Int32 in
            childKey.withUnsafeBytes { factorBytes -> Int32 in
                guard let factorPointer = factorBytes.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                guard let privateKeyPointer = privateKeyBytes.baseAddress?
                    .assumingMemoryBound(to: UInt8.self)
                else { return 0 }
                return secp256k1_ec_seckey_tweak_add(context, privateKeyPointer, factorPointer)
            }
        }) == 0 {
            throw Error.tweakFailed
        }
        return Data(rawVariable)
    }

    public func publicKey(privateKey: Data, compressed: Bool) -> Data {
        let privateKeyBytes = [UInt8](privateKey)
        var publicKey = secp256k1_pubkey()
        let context = secp256k1.Context.rawRepresentation
        _ = secp256k1_ec_pubkey_create(context, &publicKey, privateKeyBytes)
        return PublicKey.publicKey(publicKey, compressed: compressed).data
    }
}
