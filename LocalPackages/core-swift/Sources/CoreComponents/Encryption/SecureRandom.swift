import Foundation

struct SecureRandom {
  enum Error: Swift.Error {
    case generationFailed
  }
  
  private init() {}
  
  static func getRandomBytes(length: Int) throws -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: length)
    let status = SecRandomCopyBytes(
      kSecRandomDefault,
      length,
      &bytes
    )
    if status == errSecSuccess {
      return bytes
    } else {
      throw Error.generationFailed
    }
  }
}
