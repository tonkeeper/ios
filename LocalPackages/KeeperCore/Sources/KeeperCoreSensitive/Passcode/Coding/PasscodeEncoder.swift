import CryptoKit
import Foundation
import Security

enum PasscodeEncoderFailure: Error {
    case wrapKeyGenerationFailure(message: String)
    case encryptionFailure(message: String)
}

struct EncodedPasscode {
    var wrapKey: Data
    var encryptedPayload: Data
}

struct PasscodeEncoder {
    var payloadVersion: UInt8

    func encryptPasscode(
        _ passcode: String
    ) throws(PasscodeEncoderFailure) -> EncodedPasscode {
        try encryptPasscode(
            passcode,
            with: randomBytes(count: wrapKeyLength)
        )
    }
}

private extension PasscodeEncoder {
    func encryptPasscode(
        _ passcode: String,
        with wrapKey: Data
    ) throws(PasscodeEncoderFailure) -> EncodedPasscode {
        let passcodeData = Data(passcode.utf8)
        let key = SymmetricKey(data: wrapKey)
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.seal(passcodeData, using: key)
        } catch {
            throw .encryptionFailure(
                message: "failed to seal passcode data due to error: \(error)"
            )
        }
        guard let combined = sealedBox.combined else {
            throw .encryptionFailure(
                message: "missing sealed box combined data"
            )
        }
        var payload = Data([payloadVersion])
        payload.append(combined)
        return EncodedPasscode(
            wrapKey: wrapKey,
            encryptedPayload: payload
        )
    }

    func randomBytes(count: Int) throws(PasscodeEncoderFailure) -> Data {
        var data = Data(repeating: 0, count: count)
        let status = try data
            .withUnsafeMutableBytes { buffer -> Result<OSStatus, PasscodeEncoderFailure> in
                guard let baseAddress = buffer.baseAddress else {
                    return .failure(
                        .wrapKeyGenerationFailure(
                            message: "missing base address"
                        )
                    )
                }
                return .success(
                    SecRandomCopyBytes(
                        kSecRandomDefault,
                        count,
                        baseAddress
                    )
                )
            }
            .get()
        guard status == errSecSuccess else {
            throw .wrapKeyGenerationFailure(
                message: "SecRandomCopyBytes failed with code \(status)"
            )
        }
        return data
    }
}

private extension PasscodeEncoder {
    var wrapKeyLength: Int {
        32
    }
}
