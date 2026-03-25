import Foundation
import KeeperCore

final class RampPickerPaymentMethodModel: RampPickerModel {
    var didUpdateState: ((RampPickerState?) -> Void)?

    private let methods: [OnRampLayoutCashMethod]

    init(methods: [OnRampLayoutCashMethod]) {
        self.methods = methods
    }

    func getState() -> RampPickerState? {
        RampPickerState(
            mode: .paymentMethod(methods: methods),
            scrollToSelected: false
        )
    }
}
