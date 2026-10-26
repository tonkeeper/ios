import CryptoKit
import Foundation

/// Opens the credentials envelope a frame returns: `base64(JSON {iv, ephemeralPublicKey, ciphertext})`,
/// hex fields, AES-256-GCM under `HKDF-SHA256(X25519(host private, ephemeral public), salt: "", info: "")`,
/// the 16-byte tag appended to the ciphertext.
public enum MoonPayCredentialsDecryptor {
    struct Envelope: Codable, Equatable {
        let iv: String
        let ephemeralPublicKey: String
        let ciphertext: String
    }

    static let tagLength = 16
    static let keyLength = 32

    public static func decrypt(
        _ encrypted: MoonPayEncryptedCredentials,
        using keyPair: MoonPayKeyPair
    ) throws -> MoonPayCredentials {
        let plaintext = try decryptPlaintext(encrypted, using: keyPair)
        do {
            return try MoonPayJSONCoding.makeDecoder().decode(MoonPayCredentials.self, from: plaintext)
        } catch {
            throw MoonPayCryptoError.invalidPlaintext
        }
    }

    static func decryptPlaintext(_ encrypted: MoonPayEncryptedCredentials, using keyPair: MoonPayKeyPair) throws -> Data {
        let envelope = try envelope(from: encrypted)
        guard let iv = HexEncoding.decode(envelope.iv) else {
            throw MoonPayCryptoError.invalidHex(field: "iv")
        }
        guard let ephemeralPublicKey = HexEncoding.decode(envelope.ephemeralPublicKey) else {
            throw MoonPayCryptoError.invalidHex(field: "ephemeralPublicKey")
        }
        guard let ciphertextWithTag = HexEncoding.decode(envelope.ciphertext) else {
            throw MoonPayCryptoError.invalidHex(field: "ciphertext")
        }
        guard ciphertextWithTag.count > tagLength else {
            throw MoonPayCryptoError.invalidTag
        }

        let symmetricKey = try symmetricKey(sharedSecret: keyPair.sharedSecret(withEphemeralPublicKey: ephemeralPublicKey))
        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: iv),
                ciphertext: ciphertextWithTag.dropLast(tagLength),
                tag: ciphertextWithTag.suffix(tagLength)
            )
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw MoonPayCryptoError.decryptionFailed
        }
    }

    static func envelope(from encrypted: MoonPayEncryptedCredentials) throws -> Envelope {
        guard let data = Data(base64Encoded: encrypted.base64),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data)
        else {
            throw MoonPayCryptoError.invalidEnvelope
        }
        return envelope
    }

    static func symmetricKey(sharedSecret: SharedSecret) -> SymmetricKey {
        sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data(),
            outputByteCount: keyLength
        )
    }
}
