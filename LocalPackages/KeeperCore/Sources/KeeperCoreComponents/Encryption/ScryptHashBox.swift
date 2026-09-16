import CryptoKit
import CryptoSwift
import Foundation
import TweetNacl

struct ScryptHashBox {
    enum Error: Swift.Error {
        case malformedHex
    }

    private static let nonceLength = 24

    private init() {}

    static func encrypt(
        data: Data,
        salt: [UInt8],
        N: Int,
        r: Int,
        p: Int,
        password: String,
        dkLen: Int
    ) async throws -> String {
        let passwordHash = try Data(Scrypt(
            password: [UInt8](password.utf8),
            salt: salt,
            dkLen: dkLen,
            N: N,
            r: r,
            p: p
        ).calculate())

        let nonce = Data(salt[0 ..< 24])
        let secretBox = try TweetNacl.NaclSecretBox.secretBox(
            message: data,
            nonce: nonce,
            key: passwordHash
        )

        return secretBox.toHexString()
    }

    static func decrypt(
        string: String,
        salt: String,
        N: Int,
        r: Int,
        p: Int,
        password: String,
        dkLen: Int
    ) async throws -> Data {
        guard let saltData = Data(strictHex: salt), saltData.count >= nonceLength,
              let boxData = Data(strictHex: string)
        else {
            throw Error.malformedHex
        }

        let passwordHash = try Data(Scrypt(
            password: [UInt8](password.utf8),
            salt: [UInt8](saltData),
            dkLen: dkLen,
            N: N,
            r: r,
            p: p
        ).calculate())

        return try TweetNacl.NaclSecretBox.open(
            box: boxData,
            nonce: Data(saltData.prefix(nonceLength)),
            key: passwordHash
        )
    }
}
