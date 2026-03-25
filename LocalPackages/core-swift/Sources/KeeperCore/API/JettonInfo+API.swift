import BigInt
import Foundation
import TonAPI
import TonSwift

extension JettonInfo {
    init(jettonPreview: TonAPI.JettonPreview, extensions: [String]? = nil) throws {
        let tokenAddress = try Address.parse(jettonPreview.address)
        address = tokenAddress
        fractionDigits = jettonPreview.decimals
        name = jettonPreview.name
        imageURL = URL(string: jettonPreview.image)

        isTransferable = !(extensions?.contains("non_transferable") ?? false)
        hasCustomPayload = extensions?.contains("custom_payload") ?? false

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
        case .graylist:
            verification = .graylist
        }
        symbol = verification == .blacklist ? "SCAM" : jettonPreview.symbol
        self.verification = verification

        if let numerator = jettonPreview.scaledUi?.numerator {
            self.numerator = BigUInt(numerator)
        } else {
            self.numerator = nil
        }

        if let denomenator = jettonPreview.scaledUi?.denominator {
            self.denomenator = BigUInt(denomenator)
        } else {
            self.denomenator = nil
        }
    }
}
