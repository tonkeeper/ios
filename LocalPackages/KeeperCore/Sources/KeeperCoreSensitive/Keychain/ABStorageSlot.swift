import Foundation

enum ABStorageSlot: String, CaseIterable, Hashable {
    case a
    case b

    var inactive: ABStorageSlot {
        switch self {
        case .a:
            return .b
        case .b:
            return .a
        }
    }
}
