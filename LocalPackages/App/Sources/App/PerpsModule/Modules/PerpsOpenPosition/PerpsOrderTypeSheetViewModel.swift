import Foundation

@MainActor
final class PerpsOrderTypeSheetViewModel: ObservableObject {
    let selected: PerpsOrderType

    var onSelect: ((PerpsOrderType) -> Void)?
    var onClose: (() -> Void)?

    init(selected: PerpsOrderType) {
        self.selected = selected
    }

    func select(_ type: PerpsOrderType) {
        if let onSelect {
            onSelect(type)
        } else {
            onClose?()
        }
    }
}
