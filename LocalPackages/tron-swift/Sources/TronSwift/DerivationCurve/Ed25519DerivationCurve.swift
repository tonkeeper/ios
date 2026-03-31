import CryptoKit
import Foundation

public enum Ed25519DerivationCurve: DerivationCurve {
    public var seedSalt: String {
        "ed25519 seed"
    }

    public var supportNonHardened: Bool {
        false
    }

    public func derivedPrivateKey(parentPrivateKey: Data, childKey: Data) throws -> Data {
        childKey
    }

    public func publicKey(privateKey: Data, compressed: Bool) -> Data {
        do {
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
            let publicKey = privateKey.publicKey
            return publicKey.rawRepresentation
        } catch {
            return Data()
        }
    }
}
