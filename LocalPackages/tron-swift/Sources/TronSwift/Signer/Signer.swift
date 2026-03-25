import Foundation
import secp256k1

public struct Signer {
    public enum Error: Swift.Error {
        case signFailed
    }

    public init() {}

    public func sign(hash: Data, privateKey: PrivateKey) throws -> Data {
        let encrypter = Secp256k1Encrypter()
        guard var signatureInInternalFormat = encrypter.sign(hash: hash, privateKey: privateKey.data) else {
            throw Error.signFailed
        }
        return encrypter.export(signature: &signatureInInternalFormat)
    }
}
