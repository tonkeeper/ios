import Foundation
import TonSwift
import BigInt

public enum Deeplink: Equatable {

  public struct TransferData: Equatable {
    public let recipient: String
    public let amount: BigUInt?
    public let comment: String?
    public let jettonAddress: Address?
    public let expirationTimestamp: Int64?
  }
  
  public struct SwapData: Equatable {
    public let fromToken: String?
    public let toToken: String?
  }
  
  public struct Battery: Equatable {
    public let promocode: String?
  }
  
  case transfer(TransferData)
  case buyTon
  case staking
  case pool(Address)
  case exchange(provider: String)
  case swap(SwapData)
  case action(eventId: String)
  case publish(sign: Data)
  case externalSign(ExternalSignDeeplink)
  case tonconnect(TonConnectParameters)
  case dapp(URL)
  case battery(Battery)
}

public enum ExternalSignDeeplink: Equatable {
  case link(publicKey: TonSwift.PublicKey, name: String)
}
