import Foundation
import TonAPI
import TonSwift

extension JettonInfo {
  init(jettonPreview: JettonPreview) throws {
    let tokenAddress = try Address.parse(jettonPreview.address)
    address = tokenAddress
    fractionDigits = jettonPreview.decimals
    name = jettonPreview.name
    symbol = jettonPreview.symbol
    imageURL = URL(string: jettonPreview.image)
    
    let verification: JettonInfo.Verification
    switch jettonPreview.verification {
    case .whitelist:
      verification = .whitelist
    case .blacklist:
      verification = .blacklist
    case ._none:
      verification = .none
    case .unknownDefaultOpenApi:
      verification = .none
    }
    self.verification = verification
  }
}
