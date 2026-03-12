import Foundation

public protocol DerivationCurve {
    var seedSalt: String { get }
    var supportNonHardened: Bool { get }

    func derivedPrivateKey(parentPrivateKey: Data, childKey: Data) throws -> Data
    func publicKey(privateKey: Data, compressed: Bool) -> Data
}

extension DerivationCurve {
    var seedSaltData: Data {
        seedSalt.data(using: .utf8)!
    }
}
