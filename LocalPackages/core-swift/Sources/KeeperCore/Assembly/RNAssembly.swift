import Foundation
import TonSwift

public final class RNAssembly {
  
  private let coreAssembly: CoreAssembly
  
  init(coreAssembly: CoreAssembly) {
    self.coreAssembly = coreAssembly
  }

  private weak var _rnAsyncStorage: RNAsyncStorage?
  public var rnAsyncStorage: RNAsyncStorage {
    if let _rnAsyncStorage {
      return _rnAsyncStorage
    }
    let storage = RNAsyncStorage()
    _rnAsyncStorage = storage
    return storage
  }
  
  public var rnService: RNService {
    RNServiceImplementation(asyncStorage: rnAsyncStorage)
  }
}
