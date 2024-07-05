import Foundation
import KeeperCore

public struct AppInfoProvider: KeeperCore.AppInfoProvider {
  public var version: String {
    InfoProvider.appVersion() ?? ""
  }
  
  public var platform: String {
    InfoProvider.platform()
  }
  
  public var language: String {
    "en"
  }
}
