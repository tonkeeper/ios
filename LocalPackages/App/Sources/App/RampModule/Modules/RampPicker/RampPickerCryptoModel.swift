import Foundation
import KeeperCore

final class RampPickerCryptoModel: RampPickerModel {
    var didUpdateState: ((RampPickerState?) -> Void)?

    private let items: [CryptoPickerItem]
    private let selectedId: String?

    init(items: [CryptoPickerItem], selectedId: String? = nil) {
        self.items = items
        self.selectedId = selectedId
    }

    func getState() -> RampPickerState? {
        RampPickerState(
            mode: .crypto(items: items, selectedId: selectedId),
            scrollToSelected: false
        )
    }
}
