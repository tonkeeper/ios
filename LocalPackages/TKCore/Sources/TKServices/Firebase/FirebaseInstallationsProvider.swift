import FirebaseInstallations
import Foundation

public final class FirebaseInstallationsProvider {
    public init() {}

    public func getInstallationID() async -> String? {
        try? await Installations.installations().installationID()
    }
}
