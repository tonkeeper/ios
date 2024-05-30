import Foundation
import TonAPI
import TonSwift

extension JettonInfo {
  init(jettonPreview: Components.Schemas.JettonPreview) throws {
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
    case .none:
      verification = .none
    }
    self.verification = verification
  }

  init(jettonInfo: Components.Schemas.JettonInfo) throws {
    address = try Address.parse(jettonInfo.metadata.address)
    if let digits = Int(jettonInfo.metadata.decimals) {
      fractionDigits = digits
    } else {
      // Comparing to JettonPreview it should not be optional
      throw Error.failedToParseJettonInfo
    }
    name = jettonInfo.metadata.name
    symbol = jettonInfo.metadata.symbol
    if let imageString = jettonInfo.metadata.image {
      imageURL = URL(string: imageString)
    } else {
      // Comparing to JettonPreview it should not be optional
      throw Error.failedToParseJettonInfo
    }
    switch jettonInfo.verification {
    case .whitelist:
      self.verification = .whitelist
    case .blacklist:
      self.verification = .blacklist
    case .none:
      self.verification = .none
    }
  }
}

private enum Error: Swift.Error {
  case failedToParseJettonInfo
}
