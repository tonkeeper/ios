import Foundation

/// Just enough protobuf wire format to patch one scalar field inside `Transaction.raw` without
/// generating message classes. Records other than the target are copied byte for byte, so the
/// contract payload is never interpreted.
enum ProtobufWire {
    enum Error: Swift.Error {
        case malformed
    }

    struct Field {
        let number: UInt32
        let wireType: UInt8
        /// Tag and payload together, so a record can be replaced as a whole.
        let range: Range<Int>
        let varint: UInt64?
        /// The payload alone, without tag or length prefix; `nil` unless the record is
        /// length-delimited. A nested message is scanned from these bytes.
        let payload: Range<Int>?
    }

    static func tag(fieldNumber: UInt32, wireType: UInt8) -> [UInt8] {
        encodeVarint(UInt64(fieldNumber) << 3 | UInt64(wireType))
    }

    static func encodeVarint(_ value: UInt64) -> [UInt8] {
        var value = value
        var bytes = [UInt8]()
        repeat {
            var byte = UInt8(value & 0x7F)
            value >>= 7
            if value != 0 {
                byte |= 0x80
            }
            bytes.append(byte)
        } while value != 0
        return bytes
    }

    static func decodeVarint(_ bytes: [UInt8], at index: inout Int) throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var count = 0
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            count += 1
            // A tenth byte carries bit 63 only; anything above that does not fit into UInt64.
            if count == 10, byte > 0x01 {
                throw Error.malformed
            }
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return result
            }
            guard count < 10 else {
                throw Error.malformed
            }
            shift += 7
        }
        throw Error.malformed
    }

    static func scanFields(_ bytes: [UInt8]) throws -> [Field] {
        var fields = [Field]()
        var index = 0
        while index < bytes.count {
            let start = index
            let tag = try decodeVarint(bytes, at: &index)
            let fieldNumber = tag >> 3
            guard fieldNumber > 0, fieldNumber <= UInt64(UInt32.max) else {
                throw Error.malformed
            }
            let wireType = UInt8(tag & 0x07)
            var varint: UInt64?
            var payload: Range<Int>?
            switch wireType {
            case 0:
                varint = try decodeVarint(bytes, at: &index)
            case 1:
                index = try advance(index, by: 8, in: bytes)
            case 2:
                let length = try decodeVarint(bytes, at: &index)
                guard length <= UInt64(bytes.count - index) else {
                    throw Error.malformed
                }
                let payloadStart = index
                index = try advance(index, by: Int(length), in: bytes)
                payload = payloadStart ..< index
            case 5:
                index = try advance(index, by: 4, in: bytes)
            default:
                throw Error.malformed
            }
            fields.append(
                Field(
                    number: UInt32(fieldNumber),
                    wireType: wireType,
                    range: start ..< index,
                    varint: varint,
                    payload: payload
                )
            )
        }
        return fields
    }

    static func decodeHex(_ hex: String) throws -> [UInt8] {
        guard hex.count.isMultiple(of: 2), hex.allSatisfy(\.isHexDigit) else {
            throw Error.malformed
        }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< next], radix: 16) else {
                throw Error.malformed
            }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    private static func advance(_ index: Int, by count: Int, in bytes: [UInt8]) throws -> Int {
        guard bytes.count - index >= count else {
            throw Error.malformed
        }
        return index + count
    }
}
