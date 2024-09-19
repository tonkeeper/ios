import Foundation

public struct NotificationModel: Equatable {
  public enum Mode: String, Codable {
    case critical
    case warning
  }
  
  public struct Action: Equatable {
    public enum ActionType: Equatable {
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
      case .openLink(let url):
        return Action(type: .openLink(url), label: internalNotification.action.label)
      case .unknown:
        return nil
      }
    }()
  }
}
