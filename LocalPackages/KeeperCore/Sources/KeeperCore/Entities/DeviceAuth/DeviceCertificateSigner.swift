import ChainKit
import Foundation

/// Device certificate crypto. All length-prefixed encoding, hashing and ES256 signing
/// lives in ChainKit — nothing here reimplements the message layout.
protocol DeviceCertificateSigner: Sendable {
    /// New P-256 keypair; returns its private key bytes for storage.
    func generateCertificate() -> Data
    func registerProof(
        privateKey: Data,
        platform: String,
        appId: Int64,
        clientVersion: String,
        challenge: String
    ) -> DeviceProof
    func refreshProof(
        privateKey: Data,
        deviceId: String,
        refreshToken: String
    ) -> DeviceProof
}

final class ChainKitDeviceCertificateSigner: DeviceCertificateSigner, @unchecked Sendable {
    private let auth: WalletAuth

    init(auth: WalletAuth) {
        self.auth = auth
    }

    func generateCertificate() -> Data {
        auth.generateDeviceCertificate().privateKey.asData
    }

    func registerProof(
        privateKey: Data,
        platform: String,
        appId: Int64,
        clientVersion: String,
        challenge: String
    ) -> DeviceProof {
        let proof = auth.signDeviceRegisterProof(
            keyPair: keyPair(privateKey: privateKey),
            platform: platform,
            appId: appId,
            clientVersion: clientVersion,
            challenge: challenge
        )
        return DeviceProof(publicKey: proof.publicKey, signature: proof.signature)
    }

    func refreshProof(
        privateKey: Data,
        deviceId: String,
        refreshToken: String
    ) -> DeviceProof {
        let proof = auth.signDeviceRefreshProof(
            keyPair: keyPair(privateKey: privateKey),
            deviceId: deviceId,
            refreshToken: refreshToken
        )
        return DeviceProof(publicKey: proof.publicKey, signature: proof.signature)
    }

    private func keyPair(privateKey: Data) -> KeyPair {
        KeyPair.companion.fromPrivateKey(privateKey: privateKey.asKotlinByteArray)
    }
}
