import Foundation
import CryptoKit
import CryptoSwift
import TweetNacl

public struct ScryptHashBox {
  private init() {}

  public static func encrypt(data: Data, 
                             salt: [UInt8],
                             N: Int,
                             r: Int,
                             p: Int,
                             password: String,
                             dkLen: Int) async throws -> String {
    let passwordHash = Data(try Scrypt(
      password: [UInt8](password.utf8),
      salt: salt,
      dkLen: dkLen,
      N: N,
      r: r,
      p: p
    ).calculate())
    
    let nonce = Data(salt[0..<24])
    let secretBox = try TweetNacl.NaclSecretBox.secretBox(
      message: data,
      nonce: nonce,
      key: passwordHash
    )
    
    return secretBox.toHexString()
  }
  
  public static func decrypt(string: String,
                             salt: String,
                             N: Int,
                             r: Int,
                             p: Int,
                             password: String,
                             dkLen: Int) async throws -> Data {
    let passwordHash = Data(try Scrypt(
      password: [UInt8](password.utf8),
      salt: [UInt8](Data(hex: salt)),
      dkLen: dkLen,
      N: N,
      r: r,
      p: p
    ).calculate())
    
    let nonce = Data([UInt8](Data(hex: salt))[0..<24])
    
    let data = try TweetNacl.NaclSecretBox.open(box: Data(hex: string),
                                                     nonce: nonce,
                                                     key: Data(passwordHash))
    return data
  }
}
