import ChainKit
import Foundation
@testable import KeeperCore
import XCTest

/// `keeper.wallet.auth.v1` is built entirely inside chain-kit, which pins the message bytes itself.
/// What is ours is the seam: `walletAppPrivateKey` exports the app key so a token can be minted
/// later without the mnemonic, and `walletAuthToken` rebuilds a signer from those bytes. A wrong
/// wallet kind or a lossy export would still produce a well-formed token that no verifier could
/// resolve to the wallet id in `X-Wallet-ID`, and nothing else on the client would notice.
///
/// The service itself is not instantiated — it needs a keychain-backed `MnemonicAccess` — but
/// `CryptoKitClient.auth` is a stateless `WalletAuth()`, so calling it directly signs identically.
/// Both paths read `ChainKitServiceImplementation.walletKind`, so a change of kind lands here.
final class MultichainWalletAuthTokenTests: XCTestCase {
    /// Canonical BIP39 zero-entropy vector — deterministic, no secrets.
    private let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    /// A compact JWS as the device session issues it: `header.payload.signature`, dots and all.
    private let accessToken = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkZXZpY2UtaWQifQ.c2lnbmF0dXJl"
    private let otherAccessToken = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJvdGhlci1pZCJ9.c2lnbmF0dXJl"

    /// The wallet kind is secp256k1, so the token wraps a 65-byte compact recoverable signature —
    /// 87 unpadded base64url chars. An ed25519 kind would sign 64 bytes and land on 86, which is the
    /// cheapest way to catch the scheme changing under us.
    func testWalletAuthTokenIsUnpaddedBase64UrlOver65ByteSignature() throws {
        let token = try makeToken(accessToken: accessToken)

        XCTAssertEqual(token.count, 87, "65-byte secp256k1 signature -> 87 unpadded base64url chars")
        XCTAssertFalse(
            token.contains(where: { $0 == "=" || $0 == "+" || $0 == "/" }),
            "expected a header-safe url alphabet, got \(token)"
        )

        let signature = try XCTUnwrap(Self.decodeBase64Url(token), "token is not base64url")
        XCTAssertEqual(signature.count, 65)
        XCTAssertTrue(
            [0, 1].contains(signature[signature.count - 1]),
            "expected a trailing recovery id of 0 or 1, got \(signature[signature.count - 1])"
        )
    }

    /// The whole point of exporting the app key: the token minted from the stored bytes has to be
    /// the one the mnemonic-derived key would have produced, or the id a verifier recovers is not
    /// the wallet's.
    func testExportedAppKeyMintsTheSameTokenAsTheMnemonicDerivedKey() throws {
        let fromMnemonic = try makeToken(accessToken: accessToken)
        let fromExportedKey = try makeToken(accessToken: accessToken, viaExportedKey: true)

        XCTAssertEqual(fromExportedKey, fromMnemonic)
    }

    /// The binding that makes the credential session-scoped: minted for one access token, worthless
    /// against another.
    func testWalletAuthTokenIsBoundToItsAccessToken() throws {
        let token = try makeToken(accessToken: accessToken)
        let other = try makeToken(accessToken: otherAccessToken)

        XCTAssertNotEqual(token, other)
    }

    /// The access token is committed to as its raw UTF-8, so nothing about the wire string is
    /// normalized away — a client that decoded it as one base64url blob would throw on the first dot.
    func testWalletAuthTokenCommitsToTheJwsVerbatim() throws {
        let token = try makeToken(accessToken: accessToken)
        let padded = try makeToken(accessToken: accessToken + "==")

        XCTAssertNotEqual(token, padded)
    }

    /// The id that travels in `X-Wallet-ID` is the v2 format the verifier reads the version and kind
    /// bytes from: 22 bytes -> 36 base32 chars, and version 2 encodes as the leading "ai".
    func testWalletIdIsTheSelfDescribingV2Format() throws {
        let wallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)

        let walletId = wallet.walletIdV2(kind: ChainKitServiceImplementation.walletKind)

        XCTAssertEqual(walletId.count, 36)
        XCTAssertTrue(walletId.hasPrefix("ai"), "expected a version-2 prefix, got \(walletId)")
    }

    /// Mirrors `ChainKitServiceImplementation`: the mnemonic path is `walletKeyPair`, and
    /// `viaExportedKey` is `walletAppPrivateKey` followed by `walletAuthToken`.
    private func makeToken(accessToken: String, viaExportedKey: Bool = false) throws -> String {
        let wallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)
        let derived = wallet.walletKeyPair(kind: ChainKitServiceImplementation.walletKind)
        defer { derived.privateKey.fillZeros() }

        guard viaExportedKey else {
            return WalletAuth().walletAuthToken(keyPair: derived, accessToken: accessToken)
        }

        let exported = derived.privateKey.asData
        let rebuilt = WalletKeyPair.companion.fromPrivateKey(
            privateKey: exported.asKotlinByteArray,
            kind: ChainKitServiceImplementation.walletKind
        )
        defer { rebuilt.privateKey.fillZeros() }
        return WalletAuth().walletAuthToken(keyPair: rebuilt, accessToken: accessToken)
    }

    private static func decodeBase64Url(_ value: String) -> Data? {
        var standard = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = standard.count % 4
        if remainder > 0 {
            standard.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: standard)
    }
}
