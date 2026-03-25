import CoreComponents
import Foundation
import Punycode
import Sodium
import TonSwift

public struct CellSignDataSigner: SignDataSigner {
    public enum Error: Swift.Error {
        case incorrectDomain(String)
    }

    let signDataPayload: TonConnect.SignDataRequest

    public init(_ signDataPayload: TonConnect.SignDataRequest) {
        self.signDataPayload = signDataPayload
    }

    public func sign(
        wallet: Wallet,
        mnemonicsRepository: MnemonicsRepository,
        dappUrl: String,
        passcode: String
    ) async throws -> SignedDataResult {
        let address = try wallet.address

        let payload: (schema: Data, cell: String) = try {
            switch signDataPayload.params {
            case let .cell(schema, cell):
                guard let schemaData = schema.data(using: .utf8)?.crc32() else {
                    throw SignDataError.invalidDataEncoding
                }
                return (schema: schemaData, cell: cell)
            default:
                throw SignDataError.wrongPayloadType
            }
        }()

        let encodedDomain = try Self.encodeDomain(domain: dappUrl)
        guard let encodedDomainData = encodedDomain.data(using: .utf8) else {
            throw Error.incorrectDomain(encodedDomain)
        }

        let timestamp = UInt64(Date().timeIntervalSince1970)
        let builder = Builder()
        try builder.store(uint: 0x7556_9022, bits: 32)
        try builder.store(data: payload.schema)
        try builder.store(uint: timestamp, bits: 64)
        try builder.store(address)
        try builder.store(ref: Builder().store(data: encodedDomainData))
        try builder.store(ref: Cell.fromBase64(src: payload.cell))

        let mnemonic = try await mnemonicsRepository.getMnemonic(
            wallet: wallet,
            password: passcode
        )
        let keyPair = try MnemonicLegacy.anyMnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
        let sodium = Sodium()
        guard let signature = try sodium.sign.signature(
            message: builder.endCell().hash().bytes,
            secretKey: keyPair.privateKey.data.bytes
        ) else {
            throw SignDataError.signatureFailure
        }

        return SignedDataResult(
            signature: Data(signature).base64EncodedString(),
            timestamp: timestamp,
            address: address.toRaw(),
            domain: dappUrl,
            payload: signDataPayload.params
        )
    }

    enum DomainEncodeError: Swift.Error {
        case emptyDomain
        case emptyLabel
        case invalidLabel
        case encodedIsTooLong
    }

    static func encodeDomain(domain: String) throws -> String {
        guard !domain.isEmpty else { throw DomainEncodeError.emptyDomain }
        var normalized = domain.lowercased()
        if normalized.hasSuffix(".") {
            normalized.removeLast()
        }
        guard !normalized.isEmpty else {
            return "\u{0000}"
        }
        let asciiItems = try normalized.components(separatedBy: ".").map { label in
            guard !label.isEmpty else {
                throw DomainEncodeError.emptyLabel
            }

            guard let asciiData = label.idnaEncoded?.data(using: .utf8) else {
                throw DomainEncodeError.invalidLabel
            }

            let range: Range<UInt8> = 0 ..< 33
            if asciiData.count > 63 || asciiData.contains(where: { range.contains($0) }) {
                throw DomainEncodeError.invalidLabel
            }

            guard let asciiString = String(data: asciiData, encoding: .nonLossyASCII) else {
                throw DomainEncodeError.invalidLabel
            }

            return asciiString
        }

        let result = asciiItems.reversed()
            .joined(separator: "\u{0000}") + "\u{0000}"

        guard result.utf8.count <= 126 else {
            throw DomainEncodeError.encodedIsTooLong
        }

        return result
    }
}
