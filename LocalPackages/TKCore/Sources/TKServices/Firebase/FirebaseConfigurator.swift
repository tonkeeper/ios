import FirebaseCore
import FirebaseMessaging
import FirebasePerformance
import Foundation

public final class FirebaseConfigurator: NSObject {
    public static let configurator = FirebaseConfigurator()

    override private init() {}

    public func configure() {
        FirebaseApp.configure()
    }
}
