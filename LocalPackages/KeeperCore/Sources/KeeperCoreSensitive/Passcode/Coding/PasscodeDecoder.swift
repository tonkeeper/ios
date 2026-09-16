import CryptoKit
import Foundation
import Security

enum PasscodeDecoderFailure: Error {
    case invalidData
    case wrongPasscode
}

struct PasscodeDecoder {
    var payloadVersion: UInt8

    func decode(
        _ payload: Data,
        with wrapKey: Data
    ) throws(PasscodeDecoderFailure) -> String {
        guard let version = payload.first, version == payloadVersion else {
            throw .invalidData
        }
        let combined = payload.dropFirst()
        guard !combined.isEmpty else {
            throw .invalidData
        }
        let key = SymmetricKey(data: wrapKey)
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(combined: combined)
        } catch {
            throw .invalidData
        }
        let decryptedPasscodeData: Data
        do {
            decryptedPasscodeData = try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw .wrongPasscode
        }
        guard let passcode = String(data: decryptedPasscodeData, encoding: .utf8) else {
            throw .invalidData
        }
        return passcode
    }
}
