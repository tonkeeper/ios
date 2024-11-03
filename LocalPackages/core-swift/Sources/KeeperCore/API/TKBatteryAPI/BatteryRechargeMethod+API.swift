import Foundation
import TonSwift
import TKBatteryAPI

extension BatteryRechargeMethod {
  init?(method: RechargeMethodsMethodsInner) {
    switch method.type {
    case .ton:
      token = .ton
    case .jetton:
      guard let jettonMaster = method.jettonMaster,
            let jettonMasterAddress = try? Address.parse(jettonMaster) else { return nil }
      token = .jetton(Jetton(jettonMasterAddress: jettonMasterAddress))
    case .unknownDefaultOpenApi:
      return nil
    }
    
    imageURL = {
      guard let image = method.image else { return nil }
      return URL(string: image)
    }()
    
    rate = NSDecimalNumber(string: method.rate)
    symbol = method.symbol
    decimals = method.decimals
    supportGasless = method.supportGasless
    supportRecharge = method.supportRecharge
    minBootstrapValue = NSDecimalNumber(string: method.minBootstrapValue)
  }
}
