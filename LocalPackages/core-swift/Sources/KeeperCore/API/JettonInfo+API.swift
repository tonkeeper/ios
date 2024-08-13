import Foundation
import TonAPI
import TonSwift

extension JettonInfo {
  init(jettonPreview: Components.Schemas.JettonPreview, extensions: [String]? = nil) throws {
    let tokenAddress = try Address.parse(jettonPreview.address)
    address = tokenAddress
    fractionDigits = jettonPreview.decimals
    name = jettonPreview.name
    symbol = jettonPreview.symbol
    imageURL = URL(string: jettonPreview.image)
    
    isTransferable = !(extensions?.contains("non_transferable") ?? false)
    hasCustomPayload = extensions?.contains("custom_payload") ?? false

    let verification: JettonInfo.Verification
    switch jettonPreview.verification {
    case .whitelist:
      verification = .whitelist
    case .blacklist:
      verification = .blacklist
    case .none:
      verification = .none
    }
    self.verification = verification
  }
}
