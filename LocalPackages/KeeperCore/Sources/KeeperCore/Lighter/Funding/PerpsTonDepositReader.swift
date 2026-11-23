import BigInt
import Foundation
import TKLogging
import TonSwift

enum PerpsTonDepositReader {
    private static let textCommentOpBytes = 4
    private static let orderIdHexLength = 64
    private static let bocMagic = 0xB5EE_9C72

    static func read(
        _ payloads: [PerpsDepositQuotePayload],
        budget: BigUInt,
        security: PerpsSecurityConfig?
    ) throws(PerpsDepositQuoteError) -> BigUInt {
        guard let depositories = security?.relayTonDepositories, !depositories.isEmpty else {
            throw refusal("relay depository")
        }
        guard payloads.count == 1, let message = payloads.first, message.kind == .main else {
            throw refusal("payloads")
        }
        guard let destination = try? TonSwift.Address.parse(message.to), depositories.contains(destination.toRaw()) else {
            throw refusal("destination")
        }
        guard let sent = BigUInt(message.valueUnits, radix: 10), PerpsChainDepositReader.fitsBudget(sent, budget: budget) else {
            throw refusal("value")
        }
        guard let body = message.data, let comment = textComment(body),
              PerpsKeyRegistrationPreview.isHex(comment, length: orderIdHexLength, prefixed: true)
        else {
            throw refusal("body")
        }
        return sent
    }

    private static func textComment(_ body: String) -> String? {
        guard let boc = Data(base64Encoded: body.fixBase64()), let bytes = singleCellBytes(boc),
              bytes.count >= textCommentOpBytes,
              bytes.prefix(textCommentOpBytes).allSatisfy({ $0 == 0 })
        else { return nil }
        return String(data: bytes.dropFirst(textCommentOpBytes), encoding: .utf8)
    }

    private static func singleCellBytes(_ boc: Data) -> Data? {
        let bytes = [UInt8](boc)
        var cursor = 0
        func read(_ count: Int) -> Int? {
            guard count > 0, cursor + count <= bytes.count else { return nil }
            defer { cursor += count }
            return bytes[cursor ..< cursor + count].reduce(0) { $0 << 8 | Int($1) }
        }
        guard read(4) == bocMagic, let flags = read(1), let offsetBytes = read(1) else { return nil }
        let hasIndex = flags & 0x80 != 0
        let hasChecksum = flags & 0x40 != 0
        let sizeBytes = flags & 0x07
        guard flags & 0x38 == 0, (1 ... 4).contains(sizeBytes), (1 ... 4).contains(offsetBytes),
              read(sizeBytes) == 1, read(sizeBytes) == 1, read(sizeBytes) == 0,
              let cellsSize = read(offsetBytes), read(sizeBytes) == 0,
              !hasIndex || read(offsetBytes) != nil,
              read(1) == 0, let descriptor = read(1), descriptor % 2 == 0
        else { return nil }
        let length = descriptor / 2
        guard cellsSize == 2 + length, cursor + length + (hasChecksum ? 4 : 0) == bytes.count else { return nil }
        return Data(bytes[cursor ..< cursor + length])
    }

    private static func refusal(_ field: String) -> PerpsDepositQuoteError {
        Log.perps.w("Deposit from TON refused: \(field)")
        return .unexpectedTonPayment(field)
    }
}
