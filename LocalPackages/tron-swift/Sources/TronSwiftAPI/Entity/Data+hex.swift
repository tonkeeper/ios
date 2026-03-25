import Foundation

public extension Data {
    init?(hex: String) {
        var hex = hex
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }

        let len = hex.count / 2
        var data = Data(capacity: len)
        var i = hex.startIndex

        for _ in 0 ..< len {
            let j = hex.index(i, offsetBy: 2)
            let bytes = hex[i ..< j]

            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }

            i = j
        }
        self = data
    }
}

extension Data {
    func hexString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
