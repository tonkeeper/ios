import ChainKit
import Foundation

/// Sends ChainKit's node manifest request to the multichain host from the boot configuration, so it
/// takes the same regional route as the rest of the multichain API.
final class ChainKitNodeManifestHost: NSObject, ModuleNodeManifestHostProvider {
    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func baseUrl() -> String? {
        configuration.value(\.multichain.domain).absoluteString
    }
}
