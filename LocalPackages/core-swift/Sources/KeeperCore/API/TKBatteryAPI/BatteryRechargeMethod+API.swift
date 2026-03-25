import Foundation
import TKBatteryAPI
import TonSwift

extension BatteryRechargeMethod {
    init?(method: Components.Schemas.RechargeMethods.methodsPayloadPayload) {
        switch method._type {
        case .ton:
            token = .ton
        case .jetton:
            guard let jettonMaster = method.jetton_master,
                  let jettonMasterAddress = try? Address.parse(jettonMaster) else { return nil }
            token = .jetton(Jetton(jettonMasterAddress: jettonMasterAddress))
        }

        imageURL = {
            guard let image = method.image else { return nil }
            return URL(string: image)
        }()

        rate = NSDecimalNumber(string: method.rate)
        symbol = method.symbol
        decimals = method.decimals
        supportGasless = method.support_gasless
        supportRecharge = method.support_recharge
        minBootstrapValue = NSDecimalNumber(string: method.min_bootstrap_value)
    }
}
