import UIKit

public struct LedgerNetworksScreenState: Equatable {
    public struct App: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let icon: UIImage
        public let isRequired: Bool
        public let isSelected: Bool

        public init(id: String, title: String, icon: UIImage, isRequired: Bool, isSelected: Bool) {
            self.id = id
            self.title = title
            self.icon = icon
            self.isRequired = isRequired
            self.isSelected = isSelected
        }
    }

    public let title: String
    public let description: String
    public let apps: [App]
    public let isContinueEnabled: Bool

    public init(title: String, description: String, apps: [App], isContinueEnabled: Bool) {
        self.title = title
        self.description = description
        self.apps = apps
        self.isContinueEnabled = isContinueEnabled
    }
}
