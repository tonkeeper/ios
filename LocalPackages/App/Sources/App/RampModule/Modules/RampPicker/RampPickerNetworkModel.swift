import Foundation
import KeeperCore

final class RampPickerNetworkModel: RampPickerModel {
    var didUpdateState: ((RampPickerState?) -> Void)?

    private let assets: [OnRampLayoutCryptoMethod]
    private let stablecoinCode: String

    init(assets: [OnRampLayoutCryptoMethod], stablecoinCode: String) {
        self.assets = assets
        self.stablecoinCode = stablecoinCode
    }

    func getState() -> RampPickerState? {
        RampPickerState(
            mode: .network(assets: assets, stablecoinCode: stablecoinCode),
            scrollToSelected: false
        )
    }
}
