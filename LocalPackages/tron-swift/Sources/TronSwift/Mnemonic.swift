import Foundation
import TKCryptoKit

public enum Mnemonic {
    public static func mnemonicToSeed(
        mnemonic: [String],
        password: String = ""
    ) -> Data {
        let salt = "mnemonic" + password
        let mnemonicData = mnemonic
            .joined(separator: " ")
            .decomposedStringWithCompatibilityMapping
            .data(using: .utf8)!
        let saltData = salt
            .decomposedStringWithCompatibilityMapping
            .data(using: .utf8)!
        return PBKDF2.sha512(
            message: mnemonicData,
            salt: saltData,
            iterations: 2048,
            keyLength: 64
        )
    }

    public static func entropyToMnemonic(entropy: Data) -> [String] {
        let words = Mnemonic.english
        var bin = String(entropy.flatMap { ("00000000" + String($0, radix: 2)).suffix(8) })

        let hash = SHA256.hash(data: entropy)
        let bits = entropy.count * 8
        let cs = bits / 32

        let hashbits = String(hash.flatMap { ("00000000" + String($0, radix: 2)).suffix(8) })
        let checksum = String(hashbits.prefix(cs))
        bin += checksum

        var mnemonic = [String]()
        for i in 0 ..< (bin.count / 11) {
            let wi = Int(bin[bin.index(bin.startIndex, offsetBy: i * 11) ..< bin.index(bin.startIndex, offsetBy: (i + 1) * 11)], radix: 2)!
            mnemonic.append(String(words[wi]))
        }
        return mnemonic
    }
}

public extension Data {
    func subdata(in range: ClosedRange<Index>) -> Data {
        return subdata(in: range.lowerBound ..< range.upperBound)
    }
}

extension Data {
    func hexString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
