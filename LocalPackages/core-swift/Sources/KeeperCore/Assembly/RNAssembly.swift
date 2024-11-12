import Foundation
import TonSwift

public final class RNAssembly {
  
  public init() {}
  
  private weak var _rnAsyncStorage: RNAsyncStorage?
  public var rnAsyncStorage: RNAsyncStorage {
    if let _rnAsyncStorage {
      return _rnAsyncStorage
    }
    let storage = RNAsyncStorage()
    _rnAsyncStorage = storage
    return storage
  }
}
