import CommonCrypto
import Foundation

public enum PBKDF2 {
    enum Algorithm {
        case sha512

        var algorithm: CCPseudoRandomAlgorithm {
            switch self {
            case .sha512:
                return CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512)
            }
        }
    }

    public static func sha512(
        message: Data,
        salt: Data,
        iterations: Int = 100_000,
        keyLength: Int = 64
    ) -> Data {
        pbkdf(
            message: message,
            salt: salt,
            algorithm: .sha512,
            iterations: iterations,
            keyLength: keyLength
        )
    }

    private static func pbkdf(
        message: Data,
        salt: Data,
        algorithm: Algorithm,
        iterations: Int = 100_000,
        keyLength: Int = 64
    ) -> Data {
        var bytes = [UInt8](repeating: 0, count: keyLength)
        _ = bytes.withUnsafeMutableBytes { (outputBytes: UnsafeMutableRawBufferPointer) in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                message.map { Int8(bitPattern: $0) },
                message.count,
                [UInt8](salt),
                salt.count,
                CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512),
                UInt32(iterations),
                outputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                keyLength
            )
        }

        return Data(bytes)
    }
}
