import Foundation

struct KandelabrAPIHostProvider: APIHostProvider {
    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    var basePath: String {
        get async {
            let multichainURL = await configuration.multichainHost(network: .mainnet)
            var components = URLComponents()
            components.scheme = multichainURL.scheme
            components.host = multichainURL.host
            components.port = multichainURL.port
            return components.url?.absoluteString ?? multichainURL.absoluteString
        }
    }
}
