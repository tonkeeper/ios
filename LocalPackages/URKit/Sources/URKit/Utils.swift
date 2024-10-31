import Foundation

func toHex(byte: UInt8) -> String {
    String(format: "%02x", byte)
}

func toHex(data: Data) -> String {
    data.reduce(into: "") {
        $0 += toHex(byte: $1)
    }
}

extension Data {
    var hex: String {
        toHex(data: self)
    }
}

public func toByte<S>(hex: S) -> UInt8? where S: StringProtocol {
    guard hex.count == 2 else {
        return nil
    }
    return UInt8(hex, radix: 16)
}

func toData<S>(hex: S) -> Data? where S: StringProtocol {
    guard hex.count & 1 == 0 else {
        return nil
    }
    let len = hex.count / 2
    var result = Data(capacity: len)
    for i in 0..<len {
        let j = hex.index(hex.startIndex, offsetBy: i*2)
        let k = hex.index(j, offsetBy: 2)
        let hexByte = hex[j..<k]
        if var num = toByte(hex: hexByte) {
            result.append(&num, count: 1)
        } else {
            return nil
        }
    }
    return result
}

extension String {
    func chunked(into size: Int) -> [String] {
        var result: [String] = []
        var chunk = ""
        for c in self {
            chunk.append(c)
            if chunk.count == size {
                result.append(chunk)
                chunk = ""
            }
        }
        if !chunk.isEmpty {
            result.append(chunk)
        }
        return result
    }
    
    var utf8Data: Data {
        data(using: .utf8)!
    }
}

// Based on: https://gist.github.com/01GOD/3e6bb0b19a0caf138dd4b57e22122ae1
enum CRC32 {
    static var table: [UInt32] = {
        (0...255).map { i -> UInt32 in
            (0..<8).reduce(UInt32(i), { c, _ in
                (c % 2 == 0) ? (c >> 1) : (0xEDB88320 ^ (c >> 1))
            })
        }
    }()

    static func checksum(_ data: Data) -> UInt32 {
        ~(data.reduce(~UInt32(0), { crc, byte in
            (crc >> 8) ^ table[(Int(crc) ^ Int(byte)) & 0xFF]
        }))
    }

    static func checksum(_ string: String) -> UInt32 {
        checksum(string.utf8Data)
    }
}
