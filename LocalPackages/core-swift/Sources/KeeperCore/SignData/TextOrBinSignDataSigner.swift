import CoreComponents
import Foundation
import Sodium
import TonSwift

public struct TextOrBinSignDataSigner: SignDataSigner {
    let signDataPayload: TonConnect.SignDataRequest

    public init(signDataPayload: TonConnect.SignDataRequest) {
        self.signDataPayload = signDataPayload
    }

    public func sign(
        wallet: Wallet,
        mnemonicsRepository: MnemonicsRepository,
        dappUrl: String,
        passcode: String
    ) async throws -> SignedDataResult {
        guard let prefix = "ton-connect/sign-data/".data(using: .utf8) else {
            throw SignDataError.invalidDataEncoding
        }

        guard let payloadPrefix: Data = {
            switch signDataPayload.params {
            case .text:
                return "txt".data(using: .utf8)
            case .binary:
                return "bin".data(using: .utf8)
            default:
                return nil
            }
        }() else {
            throw SignDataError.invalidDataEncoding
        }

        let address = try wallet.address

        let addressWorkchain = UInt32(bigEndian: UInt32(address.workchain))
        let addressWorkchainData = withUnsafeBytes(of: addressWorkchain) { a in
            Data(a)
        }
        let addressHash = address.hash

        let timestampUint64 = UInt64(Date().timeIntervalSince1970)
        let timestamp = withUnsafeBytes(of: UInt64(bigEndian: timestampUint64)) { a in
            Data(a)
        }

        guard let domainData = dappUrl.data(using: .utf8) else {
            throw SignDataError.invalidDataEncoding
        }

        let domainLength = withUnsafeBytes(of: UInt32(bigEndian: UInt32(domainData.count))) { a in
            Data(a)
        }

        let payload: Data = try {
            switch signDataPayload.params {
            case let .text(text):
                guard let textData = text.data(using: .utf8) else {
                    throw SignDataError.invalidDataEncoding
                }
                return textData
            case let .binary(data):
                guard let binaryData = Data(base64Encoded: data) else {
                    throw SignDataError.invalidDataEncoding
                }
                return binaryData
            default:
                throw SignDataError.wrongPayloadType
            }
        }()

        let payloadLength = UInt32(bigEndian: UInt32(payload.count))
        let payloadLengthData = withUnsafeBytes(of: payloadLength) { a in
            Data(a)
        }

        guard let ffff = Data(hex: "ffff") else {
            throw SignDataError.invalidDataEncoding
        }

        let message = ffff + prefix + addressWorkchainData + addressHash + domainLength + domainData + timestamp + payloadPrefix + payloadLengthData + payload

        let signatureDataHash = message.sha256()

        let mnemonic = try await mnemonicsRepository.getMnemonic(
            wallet: wallet,
            password: passcode
        )
        let keyPair = try MnemonicLegacy.anyMnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)

        let sodium = Sodium()
        guard let signature = sodium.sign.signature(
            message: signatureDataHash.bytes,
            secretKey: keyPair.privateKey.data.bytes
        ) else {
            throw SignDataError.signatureFailure
        }

        return SignedDataResult(
            signature: Data(signature).base64EncodedString(),
            timestamp: timestampUint64,
            address: address.toRaw(),
            domain: dappUrl,
            payload: signDataPayload.params
        )
    }
}
