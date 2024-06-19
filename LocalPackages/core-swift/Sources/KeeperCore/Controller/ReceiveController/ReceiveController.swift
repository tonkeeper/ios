import Foundation
import TonSwift

public final class ReceiveController {
  public struct Model {
    public let wallet: Wallet
    public let tokenName: String
    public let descriptionTokenName: String
    public let image: TokenImage
  }
  
  public var didUpdateModel: ((Model) -> Void)?

  private let token: Token
  private let walletsStore: WalletsStore
  private let deeplinkGenerator: DeeplinkGenerator
  
  init(token: Token,
       walletsStore: WalletsStore,
       deeplinkGenerator: DeeplinkGenerator) {
    self.token = token
    self.walletsStore = walletsStore
    self.deeplinkGenerator = deeplinkGenerator
  }
  
  public func qrCodeString() -> String {
    let jettonAddress: Address?
    switch token {
    case .ton:
      jettonAddress = nil
    case .jetton(let jettonItem):
      jettonAddress = jettonItem.jettonInfo.address
    }
    do {
      return try deeplinkGenerator.generateTransferDeeplink(
        with: walletsStore.activeWallet.address.toString(bounceable: false), jettonAddress: jettonAddress
      ).string
    } catch {
      return ""
    }
  }
  
  public func createModel() {
    let tokenName: String
    let descriptionTokenName: String
    let image: TokenImage
    
    switch token {
    case .ton:
      tokenName = TonInfo.name
      descriptionTokenName = "\(TonInfo.name) \(TonInfo.symbol)"
      image = .ton
    case .jetton(let jettonItem):
      tokenName = jettonItem.jettonInfo.symbol ?? jettonItem.jettonInfo.name
      descriptionTokenName = jettonItem.jettonInfo.symbol ?? jettonItem.jettonInfo.name
      image = .url(jettonItem.jettonInfo.imageURL)
    }
    
    didUpdateModel?(
      Model(
        wallet: walletsStore.activeWallet,
        tokenName: tokenName,
        descriptionTokenName: descriptionTokenName,
        image: image
      )
    )
  }
}
