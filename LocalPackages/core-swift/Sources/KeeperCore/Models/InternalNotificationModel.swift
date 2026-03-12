import Foundation

public struct NotificationModel: Codable, Hashable {
    public enum Mode: String, Codable {
        case critical
        case warning
    }

    public struct Action: Equatable, Codable {
        public enum ActionType: Equatable, Codable {
            case openLink(URL?)
        }

        public let type: ActionType
        public let label: String
    }

    public let id: String
    public let title: String
    public let caption: String
    public let mode: Mode
    public let action: Action?
}

public extension NotificationModel {
    static func == (lhs: NotificationModel, rhs: NotificationModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension NotificationModel {
    init(internalNotification: InternalNotification) {
        self.id = internalNotification.id
        self.title = internalNotification.title
        self.caption = internalNotification.caption
        self.mode = {
            switch internalNotification.mode {
            case .warning:
                return .warning
            }
        }()
        self.action = {
            switch internalNotification.action.type {
            case let .openLink(url):
                return Action(type: .openLink(url), label: internalNotification.action.label)
            case .unknown:
                return nil
            }
        }()
    }
}
