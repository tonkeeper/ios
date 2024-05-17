import Foundation
import CoreComponents

public protocol SignerInfoRepository {
    func getSignerInfo() throws -> SignerInfo
    func saveSignerInfo(_ signerInfo: SignerInfo) throws
    func removeSignerInfo() throws
}

extension FileSystemVault<SignerInfo, String>: SignerInfoRepository {
  public func getSignerInfo() throws -> SignerInfo {
    try loadItem(key: String.signerInfoKey)
  }
  
  public func saveSignerInfo(_ signerInfo: SignerInfo) throws {
    try saveItem(signerInfo, key: .signerInfoKey)
  }
  
  public func removeSignerInfo() throws {
    try deleteItem(key: .signerInfoKey)
  }
}

private extension String {
  static let signerInfoKey = "SignerInfo"
}
