import KeeperCore
import TKCore
import UIKit

struct BatteryPromocodeInputAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        promocodeStore: BatteryPromocodeStore,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) -> MVVMModule<BatteryPromocodeInputViewController, BatteryPromocodeInputModuleOutput, Void> {
        let viewController = BatteryPromocodeInputViewController(
            wallet: wallet,
            batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
            batteryPromocodeStore: promocodeStore
        )

        return MVVMModule(
            view: viewController,
            output: viewController,
            input: ()
        )
    }
}
