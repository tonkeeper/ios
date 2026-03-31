import CoreComponents
import Foundation
import TonSwift

public protocol BatteryRechargeMethodsRepository {
    func getRechargeMethods(rechargeOnly: Bool, network: Network) -> [BatteryRechargeMethod]
    func saveRechargeMethods(_methods: [BatteryRechargeMethod], rechargeOnly: Bool, network: Network) throws
}

struct BatteryRechargeMethodsRepositoryImplementation: BatteryRechargeMethodsRepository {
    let fileSystemVault: FileSystemVault<[BatteryRechargeMethod], String>

    func getRechargeMethods(
        rechargeOnly: Bool,
        network: Network
    ) -> [BatteryRechargeMethod] {
        do {
            return try fileSystemVault.loadItem(key: key(rechargeOnly: rechargeOnly, network: network))
        } catch {
            return []
        }
    }

    func saveRechargeMethods(
        _methods: [BatteryRechargeMethod],
        rechargeOnly: Bool,
        network: Network
    ) throws {
        try fileSystemVault.saveItem(_methods, key: key(rechargeOnly: rechargeOnly, network: network))
    }

    private func key(rechargeOnly: Bool, network: Network) -> String {
        return "recharge_methods\(rechargeOnly ? "_recharge_only" : "")_\(network.rawValue)"
    }
}
