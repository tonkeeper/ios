import Foundation
import FirebaseCore
import FirebaseMessaging
import FirebaseAnalytics
import FirebasePerformance

public final class FirebaseConfigurator: NSObject {
  
  public static let configurator = FirebaseConfigurator()
  
  private override init() {}
  
  public func configure() {
    FirebaseApp.configure()
  }
}
