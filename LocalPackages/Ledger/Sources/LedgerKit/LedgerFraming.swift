import Foundation

enum LedgerFraming {
    static let apduTag: UInt8 = 0x05
    static let mtuTag: UInt8 = 0x08
    static let minFrameSize = 20
    static let mtuRequest = Data([mtuTag, 0x00, 0x00, 0x00, 0x00])

    static func frames(of apdu: Data, frameSize: Int) -> [Data] {
        let bytes = [UInt8](apdu)
        let firstCapacity = frameSize - 5
        let nextCapacity = frameSize - 3
        let bodies = [bytes.prefix(firstCapacity)] + stride(from: firstCapacity, to: bytes.count, by: nextCapacity).map {
            bytes[$0 ..< min($0 + nextCapacity, bytes.count)]
        }
        return bodies.enumerated().map { index, body in
            let length = index == 0 ? [UInt8(bytes.count >> 8), UInt8(bytes.count & 0xFF)] : []
            return Data([apduTag, UInt8(index >> 8), UInt8(index & 0xFF)] + length + body)
        }
    }

    static func frameSize(mtuReply: Data) -> Int? {
        let bytes = [UInt8](mtuReply)
        guard bytes.count >= 6, bytes[0] == mtuTag, Int(bytes[5]) >= minFrameSize else {
            return nil
        }
        return Int(bytes[5])
    }
}

enum LedgerFrameAssembly: Equatable {
    case empty
    case collecting(length: Int, body: Data, nextIndex: Int)

    var response: Data? {
        guard case let .collecting(length, body, _) = self, body.count == length else {
            return nil
        }
        return body
    }

    func appending(_ frame: Data) throws -> LedgerFrameAssembly {
        let bytes = [UInt8](frame)
        guard bytes.count >= 3, bytes[0] == LedgerFraming.apduTag else {
            throw LedgerTransportError.invalidResponse
        }
        let index = Int(bytes[1]) << 8 | Int(bytes[2])
        switch self {
        case .empty:
            guard index == 0, bytes.count >= 5 else {
                throw LedgerTransportError.invalidResponse
            }
            let length = Int(bytes[3]) << 8 | Int(bytes[4])
            return .collecting(length: length, body: Data(bytes[5...].prefix(length)), nextIndex: 1)
        case let .collecting(length, body, nextIndex):
            guard index == nextIndex else {
                throw LedgerTransportError.invalidResponse
            }
            return .collecting(length: length, body: body + bytes[3...].prefix(length - body.count), nextIndex: nextIndex + 1)
        }
    }
}
