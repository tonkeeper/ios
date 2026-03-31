import CommonCrypto
import Foundation

public enum HMAC {
    enum Algorithm {
        case sha256
        case sha512

        var digestLength: Int {
            switch self {
            case .sha256:
                Int(CC_SHA256_DIGEST_LENGTH)
            case .sha512:
                Int(CC_SHA512_DIGEST_LENGTH)
            }
        }

        var algorithm: CCHmacAlgorithm {
            switch self {
            case .sha256:
                return CCHmacAlgorithm(kCCHmacAlgSHA256)
            case .sha512:
                return CCHmacAlgorithm(kCCHmacAlgSHA512)
            }
        }
    }

    public static func sha256(message: Data, key: Data) -> Data {
        hmac(message: message, key: key, algorithm: .sha256)
    }

    public static func sha512(message: Data, key: Data) -> Data {
        hmac(message: message, key: key, algorithm: .sha512)
    }

    private static func hmac(message: Data, key: Data, algorithm: Algorithm) -> Data {
        let count = algorithm.digestLength
        var outputBuffer = [UInt8](repeating: 0, count: count)

        key.withUnsafeBytes { bufferPointer in
            guard let keyPointer = bufferPointer.baseAddress else { return }
            message.withUnsafeBytes { bufferPointer in
                guard let messagePointer = bufferPointer.baseAddress else { return }
                CCHmac(
                    algorithm.algorithm,
                    keyPointer,
                    key.count,
                    messagePointer,
                    message.count,
                    &outputBuffer
                )
            }
        }
        return Data(bytes: outputBuffer, count: count)
    }
}
