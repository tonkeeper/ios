import Foundation
import TKCryptoKit

public struct PrivateKey: Key, Equatable, Codable {
    public enum DerivationError: Swift.Error {
        case invalidIndex(UInt32)
        case nonHardenedDeriveFailed
    }

    public let data: Data
    public let chainCode: Data

    public init(
        data: Data,
        chainCode: Data
    ) {
        self.data = data
        self.chainCode = chainCode
    }

    public func deriveKey(index: UInt32, hardened: Bool, curve: DerivationCurve) throws -> PrivateKey {
        let edge: UInt32 = 0x8000_0000
        guard (edge & index) == 0 else {
            throw DerivationError.invalidIndex(index)
        }

        if !hardened && !curve.supportNonHardened {
            throw DerivationError.nonHardenedDeriveFailed
        }

        var data = Data()
        let publicKey = curve.publicKey(privateKey: self.data, compressed: true)
        if hardened {
            data += Data([0])
            data += self.data
        } else {
            data += publicKey
        }

        var derivingIndex = CFSwapInt32BigToHost(hardened ? (edge | index) : index)
        data += Data(bytes: &derivingIndex, count: MemoryLayout<UInt32>.size)

        let digest = HMAC.sha512(message: data, key: chainCode)

        let derivedPrivateKey = try curve.derivedPrivateKey(parentPrivateKey: self.data, childKey: digest[0 ..< 32])
        let derivedChainCode = digest[32 ..< 64]

        return PrivateKey(data: derivedPrivateKey, chainCode: derivedChainCode)
    }

    public func publicKey(compressed: Bool = true, curve: DerivationCurve) -> PublicKey {
        let publicKeyData = curve.publicKey(privateKey: self.data, compressed: compressed)
        return PublicKey(data: publicKeyData)
    }
}
