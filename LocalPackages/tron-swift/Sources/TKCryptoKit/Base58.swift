import Foundation

public enum Base58 {
    static let alphabets: [UInt8] = [UInt8]("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    static let zero: UInt8 = 49
    static let base: Int = 58

    public static func encode(_ data: Data) -> String {
        var data = data
        var zerosCount = 0

        for byte in data {
            if byte != 0 { break }
            zerosCount += 1
        }

        data.removeFirst(zerosCount)

        let signPart = convertBytesToBase58([UInt8](data))
        let zeroesPart = Data(repeating: zero, count: zerosCount)

        return String(data: zeroesPart + signPart, encoding: .utf8) ?? ""
    }

    public static func decode(_ string: String) -> Data {
        guard !string.isEmpty else { return Data() }
        let stringBytes = string.utf8

        var zeroesCount = 0
        for byte in stringBytes {
            guard byte == zero else { break }
            zeroesCount += 1
        }

        let resultSize = sizeFromBase(size: stringBytes.count - zeroesCount)
        var result = [UInt8](Array(repeating: 0, count: resultSize))

        var count = 0
        for byte in stringBytes {
            guard let index = alphabets.firstIndex(of: byte) else { return Data() }
            var carry = index
            var i = 0
            for j in (0 ... resultSize - 1).reversed() {
                guard carry != 0 || i < count else { break }
                carry += base * Int(result[j])
                result[j] = UInt8(carry % 256)
                carry /= 256
                i += 1
            }
            count = i
        }

        var leadingZeroes = 0
        while result[leadingZeroes] == 0 {
            leadingZeroes += 1
            guard leadingZeroes < resultSize else { return Data() }
        }

        return Data(repeating: 0, count: zeroesCount) + result[leadingZeroes...]
    }

    static func convertBytesToBase58(_ bytes: [UInt8]) -> [UInt8] {
        let resultSize = sizeFromByte(size: bytes.count)
        var result = [UInt8](Array(repeating: 0, count: resultSize))

        var count = 0
        for byte in bytes {
            var carry = Int(byte)
            var i = 0
            for j in (0 ... resultSize - 1).reversed() {
                guard carry != 0 || i < count else {
                    break
                }
                carry += 256 * Int(result[j])
                result[j] = UInt8(carry % base)
                carry /= base
                i += 1
            }
            count = i
        }

        var leadingZeroes = 0
        while result[leadingZeroes] == 0 {
            leadingZeroes += 1
        }

        return result[leadingZeroes...].map { alphabets[Int($0)] }
    }

    static func sizeFromByte(size: Int) -> Int {
        size * 138 / 100 + 1
    }

    static func sizeFromBase(size: Int) -> Int {
        size * 733 / 1000 + 1
    }
}

public extension String {
    var decodeBase58: Data {
        Base58.decode(self)
    }
}

public extension Data {
    var encodeBase58: String {
        Base58.encode(self)
    }
}
