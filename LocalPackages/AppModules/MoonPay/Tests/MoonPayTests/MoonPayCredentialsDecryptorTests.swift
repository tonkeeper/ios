import CryptoKit
@testable import MoonPay
import XCTest

final class MoonPayCredentialsDecryptorTests: XCTestCase {
    private let plaintext = #"{"accessToken":"access-1","clientToken":"client-1","expiresAt":"2026-03-27T12:30:00.000Z"}"#

    func testRoundTrip() throws {
        let keyPair = MoonPayKeyPair()
        let encrypted = try Self.encrypt(plaintext, to: keyPair)

        let credentials = try MoonPayCredentialsDecryptor.decrypt(encrypted, using: keyPair)

        XCTAssertEqual(credentials.accessToken, "access-1")
        XCTAssertEqual(credentials.clientToken, "client-1")
        XCTAssertEqual(credentials.expiresAt, MoonPayJSONCoding.parseISO8601("2026-03-27T12:30:00.000Z"))
    }

    func testPublicKeyHexIsRaw32ByteKey() {
        let keyPair = MoonPayKeyPair()
        XCTAssertEqual(keyPair.publicKeyHex.count, 64)
        XCTAssertNotNil(HexEncoding.decode(keyPair.publicKeyHex))
        XCTAssertNotEqual(MoonPayKeyPair().publicKeyHex, keyPair.publicKeyHex)
    }

    func testWrongRecipientFails() throws {
        let encrypted = try Self.encrypt(plaintext, to: MoonPayKeyPair())
        XCTAssertThrowsError(try MoonPayCredentialsDecryptor.decrypt(encrypted, using: MoonPayKeyPair())) { error in
            XCTAssertEqual(error as? MoonPayCryptoError, .decryptionFailed)
        }
    }

    func testTamperedCiphertextFails() throws {
        let keyPair = MoonPayKeyPair()
        let encrypted = try Self.encrypt(plaintext, to: keyPair, tamperLastByte: true)
        XCTAssertThrowsError(try MoonPayCredentialsDecryptor.decrypt(encrypted, using: keyPair)) { error in
            XCTAssertEqual(error as? MoonPayCryptoError, .decryptionFailed)
        }
    }

    func testMalformedEnvelopes() throws {
        let keyPair = MoonPayKeyPair()
        XCTAssertEqual(
            try Self.cryptoError(MoonPayCredentialsDecryptor.decrypt(MoonPayEncryptedCredentials(base64: "not base64!"), using: keyPair)),
            .invalidEnvelope
        )
        XCTAssertEqual(
            try Self.cryptoError(MoonPayCredentialsDecryptor.decrypt(Self.envelope(iv: "zz", ephemeralPublicKey: "00", ciphertext: "00"), using: keyPair)),
            .invalidHex(field: "iv")
        )
        XCTAssertEqual(
            try Self.cryptoError(MoonPayCredentialsDecryptor.decrypt(Self.envelope(iv: "00", ephemeralPublicKey: "0", ciphertext: "00"), using: keyPair)),
            .invalidHex(field: "ephemeralPublicKey")
        )
        XCTAssertEqual(
            try Self.cryptoError(MoonPayCredentialsDecryptor.decrypt(Self.envelope(iv: "00", ephemeralPublicKey: "00", ciphertext: "0g"), using: keyPair)),
            .invalidHex(field: "ciphertext")
        )
        XCTAssertEqual(
            try Self.cryptoError(MoonPayCredentialsDecryptor.decrypt(Self.envelope(iv: "00", ephemeralPublicKey: "00", ciphertext: String(repeating: "00", count: 16)), using: keyPair)),
            .invalidTag
        )
        XCTAssertEqual(
            try Self.cryptoError(MoonPayCredentialsDecryptor.decrypt(Self.envelope(iv: "00", ephemeralPublicKey: "00", ciphertext: String(repeating: "00", count: 17)), using: keyPair)),
            .invalidEphemeralPublicKey
        )
    }

    func testPlaintextMustBeCredentialsJSON() throws {
        let keyPair = MoonPayKeyPair()
        let encrypted = try Self.encrypt(#"{"accessToken":"only"}"#, to: keyPair)
        XCTAssertEqual(try Self.cryptoError(MoonPayCredentialsDecryptor.decrypt(encrypted, using: keyPair)), .invalidPlaintext)
    }

    // MARK: - Helpers

    /// The frame side of the scheme: an ephemeral X25519 key, HKDF-SHA256 over the shared secret,
    /// AES-GCM with the tag appended to the ciphertext, hex fields, base64 JSON envelope.
    private static func encrypt(_ plaintext: String, to keyPair: MoonPayKeyPair, tamperLastByte: Bool = false) throws -> MoonPayEncryptedCredentials {
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let hostPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: XCTUnwrap(HexEncoding.decode(keyPair.publicKeyHex)))
        let sharedSecret = try ephemeral.sharedSecretFromKeyAgreement(with: hostPublicKey)
        let key = MoonPayCredentialsDecryptor.symmetricKey(sharedSecret: sharedSecret)
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: key, nonce: nonce)

        var ciphertextWithTag = sealed.ciphertext + sealed.tag
        if tamperLastByte {
            ciphertextWithTag[ciphertextWithTag.count - 1] ^= 0xFF
        }
        return envelope(
            iv: HexEncoding.encode(nonce.withUnsafeBytes { Data($0) }),
            ephemeralPublicKey: HexEncoding.encode(ephemeral.publicKey.rawRepresentation),
            ciphertext: HexEncoding.encode(ciphertextWithTag)
        )
    }

    private static func envelope(iv: String, ephemeralPublicKey: String, ciphertext: String) -> MoonPayEncryptedCredentials {
        let json = try! JSONEncoder().encode(MoonPayCredentialsDecryptor.Envelope(iv: iv, ephemeralPublicKey: ephemeralPublicKey, ciphertext: ciphertext))
        return MoonPayEncryptedCredentials(base64: json.base64EncodedString())
    }

    private static func cryptoError<T>(_ expression: @autoclosure () throws -> T) -> MoonPayCryptoError? {
        do {
            _ = try expression()
            return nil
        } catch {
            return error as? MoonPayCryptoError
        }
    }
}
