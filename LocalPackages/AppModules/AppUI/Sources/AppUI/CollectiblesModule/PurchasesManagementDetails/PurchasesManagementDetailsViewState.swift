import Foundation

public struct PurchasesManagementDetailsViewState {
    public struct Item: Identifiable {
        public enum Accessory {
            case copy
            case image(URL?)
        }

        public let id: String
        public let title: String
        public let value: String
        public let accessory: Accessory?
        public let copyValue: String?

        public init(
            id: String,
            title: String,
            value: String,
            accessory: Accessory? = nil,
            copyValue: String? = nil
        ) {
            self.id = id
            self.title = title
            self.value = value
            self.accessory = accessory
            self.copyValue = copyValue
        }
    }

    public struct Button {
        public let title: String
        public let action: () -> Void

        public init(
            title: String,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.action = action
        }
    }

    public let title: String
    public let items: [Item]
    public let button: Button

    public init(
        title: String,
        items: [Item],
        button: Button
    ) {
        self.title = title
        self.items = items
        self.button = button
    }
}

/// Identity for presenting the details as a bottom sheet; the state itself carries closures and so
/// cannot be `Hashable` on its own.
public struct PurchasesManagementDetailsPresentation: Hashable {
    public let id: String
    public let state: PurchasesManagementDetailsViewState

    public init(id: String, state: PurchasesManagementDetailsViewState) {
        self.id = id
        self.state = state
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
