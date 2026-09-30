import Foundation
import TKCryptoKit

public extension Transaction {
    enum WireFormatError: Swift.Error {
        case alreadySigned
        case malformedRawData
        case expirationOverflow
        case missingSignature
        case malformedSignature
    }

    /// The signed `Transaction` message `wallet/broadcasthex` parses: `raw_data` in field 1 and
    /// `signature` in field 2, both length-delimited. The raw data travels as the very bytes the
    /// signature was produced over, so the node cannot rebuild it into something else.
    func signedProtobufHex() throws -> String {
        guard let signature else {
            throw WireFormatError.missingSignature
        }
        let signatureBytes: [UInt8]
        do {
            signatureBytes = try ProtobufWire.decodeHex(signature)
        } catch {
            throw WireFormatError.malformedSignature
        }
        guard !signatureBytes.isEmpty else {
            throw WireFormatError.malformedSignature
        }

        let rawData = try rawDataBytes()
        let envelope = ProtobufWire.tag(fieldNumber: 1, wireType: 2)
            + ProtobufWire.encodeVarint(UInt64(rawData.count))
            + rawData
            + ProtobufWire.tag(fieldNumber: 2, wireType: 2)
            + ProtobufWire.encodeVarint(UInt64(signatureBytes.count))
            + signatureBytes
        return Data(envelope).hexString()
    }

    /// `SHA256(raw_data)` — the digest a TRON signature is produced over, decoded strictly so a
    /// malformed `raw_data_hex` cannot turn into a signature over the wrong bytes.
    func signingDigest() throws -> TxID {
        try SHA256.hash(data: Data(rawDataBytes()))
    }

    /// Rewrites the `expiration` varint inside `raw_data_hex` and recomputes `txID` from the
    /// patched bytes. Every other record — the contract among them — is copied verbatim.
    func extendingExpiration(byMilliseconds milliseconds: Int64) throws -> Transaction {
        guard signature == nil else {
            throw WireFormatError.alreadySigned
        }

        let bytes = try rawDataBytes()
        let encoded = try encodedExpiration(in: bytes)

        // A record the hex omits defaults to 0; either way the two halves of the transaction must
        // already agree, otherwise we would sign bytes the JSON does not describe.
        guard rawData.expiration >= 0, encoded.value == UInt64(rawData.expiration) else {
            throw WireFormatError.malformedRawData
        }

        let (extended, overflow) = rawData.expiration.addingReportingOverflow(milliseconds)
        guard !overflow, extended >= 0 else {
            throw WireFormatError.expirationOverflow
        }

        let record = ProtobufWire.tag(fieldNumber: Transaction.expirationFieldNumber, wireType: 0)
            + ProtobufWire.encodeVarint(UInt64(extended))
        var patched = bytes
        if let range = encoded.range {
            patched.replaceSubrange(range, with: record)
        } else {
            patched.append(contentsOf: record)
        }

        var rawData = rawData
        rawData.expiration = extended
        let patchedData = Data(patched)
        return Transaction(
            isVisible: isVisible,
            txID: SHA256.hash(data: patchedData).hexString(),
            rawDataHex: patchedData.hexString(),
            rawData: rawData,
            signature: nil
        )
    }
}

extension Transaction {
    func rawDataBytes() throws -> [UInt8] {
        do {
            return try ProtobufWire.decodeHex(rawDataHex)
        } catch {
            throw WireFormatError.malformedRawData
        }
    }
}

private extension Transaction {
    static let expirationFieldNumber: UInt32 = 8

    /// `range` is `nil` when the record is absent and has to be appended.
    typealias EncodedExpiration = (value: UInt64, range: Range<Int>?)

    func encodedExpiration(in bytes: [UInt8]) throws -> EncodedExpiration {
        let fields: [ProtobufWire.Field]
        do {
            fields = try ProtobufWire.scanFields(bytes)
        } catch {
            throw WireFormatError.malformedRawData
        }

        let matches = fields.filter { $0.number == Transaction.expirationFieldNumber }
        switch matches.count {
        case 0:
            return (0, nil)
        case 1:
            guard let value = matches[0].varint else {
                throw WireFormatError.malformedRawData
            }
            return (value, matches[0].range)
        default:
            // Duplicates are last-wins in protobuf, but a node never emits them here, so picking
            // one would be guesswork.
            throw WireFormatError.malformedRawData
        }
    }
}
