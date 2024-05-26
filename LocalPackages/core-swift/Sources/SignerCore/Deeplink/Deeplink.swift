import Foundation
import TonSwift

public enum Deeplink {
  case tonsign(TonsignDeeplink)
}

public struct TonSignModel {
  public let publicKey: TonSwift.PublicKey
  public let body: Data
  public let returnURL: String?
  public let version: String?
  public let network: String?
}

public enum TonsignDeeplink {
  case plain
  case sign(TonSignModel)
}
