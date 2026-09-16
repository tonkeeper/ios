import KeeperCore
import TKCore

struct BatteryPromocodeInputAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        promocodeStore: BatteryPromocodeStore,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> BatteryPromocodeInputViewModel {
        BatteryPromocodeInputViewModel(
            wallet: wallet,
            batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
            batteryPromocodeStore: promocodeStore
        )
    }
}
