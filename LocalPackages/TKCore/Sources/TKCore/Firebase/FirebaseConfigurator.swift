import Foundation
import FirebaseCore
import FirebaseMessaging

public final class FirebaseConfigurator: NSObject {
  
  public static let configurator = FirebaseConfigurator()
  
  private override init() {}
  
  public func configure() {
    FirebaseApp.configure()
  }
}
