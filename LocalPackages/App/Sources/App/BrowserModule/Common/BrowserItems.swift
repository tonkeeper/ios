import Foundation

enum Browser {
    struct AppItem: Hashable, Identifiable {
        let id: String
        let configuration: BrowserAppCollectionViewCell.Configuration
        let selectionHandler: (() -> Void)?
        let longPressHandler: (() -> Void)?

        static func == (lhs: AppItem, rhs: AppItem) -> Bool {
            return lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
}
