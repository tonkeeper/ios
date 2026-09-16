import CryptoKit
import Foundation

struct QrCodeMatrixCacheKey: Hashable, Sendable {
    var string: String
    var correctionLevel: String
}

extension QrCodeMatrixCacheKey: CustomStringConvertible {
    var description: String {
        "qr_mat_\(hashedString)_\(correctionLevel)"
    }

    private var hashedString: String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
