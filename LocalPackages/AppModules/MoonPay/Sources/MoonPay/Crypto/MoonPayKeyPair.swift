import CryptoKit
import Foundation

/// Ephemeral X25519 key pair a frame encrypts credentials to. One pair per frame; it never leaves
/// memory and dies with its owner.
public final class MoonPayKeyPair {
    private let privateKey: Curve25519.KeyAgreement.PrivateKey
    public let publicKeyHex: String

    public convenience init() {
        self.init(privateKey: Curve25519.KeyAgreement.PrivateKey())
    }

    init(privateKey: Curve25519.KeyAgreement.PrivateKey) {
        self.privateKey = privateKey
        publicKeyHex = HexEncoding.encode(privateKey.publicKey.rawRepresentation)
    }

    func sharedSecret(withEphemeralPublicKey rawRepresentation: Data) throws -> SharedSecret {
        let ephemeralPublicKey: Curve25519.KeyAgreement.PublicKey
        do {
            ephemeralPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: rawRepresentation)
        } catch {
            throw MoonPayCryptoError.invalidEphemeralPublicKey
        }
        return try privateKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey)
    }
}
