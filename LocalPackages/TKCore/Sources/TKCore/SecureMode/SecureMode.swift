import Foundation
import KeeperCore

public final class SecureMode: Store<Bool> {
  private var observations = [UUID: (Bool) -> Void]()
  
  public var isSecure: Bool {
    get async {
      await getState()
    }
  }
  
  private var appSettings: AppSettings
  
  public init(appSettings: AppSettings) {
    self.appSettings = appSettings
    super.init(state: appSettings.isSecureMode)
  }
  
  public func toggle() async {
    await updateState { state in
      return StateUpdate(newState: !state)
    }
  }
}

