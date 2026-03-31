import Foundation
import KeeperCore

final class RampPickerCurrencyModel: RampPickerModel {
    var didUpdateState: ((RampPickerState?) -> Void)?

    private let currencies: [RemoteCurrency]
    private let selected: RemoteCurrency?

    init(currencies: [RemoteCurrency], selected: RemoteCurrency?) {
        self.currencies = currencies
        self.selected = selected
    }

    func getState() -> RampPickerState? {
        return RampPickerState(
            mode: .currency(currencies: currencies, selected: selected),
            scrollToSelected: false
        )
    }
}
