import Foundation
import TonAPI
import TonSwift

public protocol JettonService {
    func jettonInfo(address: Address, network: Network) async throws -> JettonInfo
}

final class JettonServiceImplementation: JettonService {
    private let apiProvider: APIProvider

    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }

    func jettonInfo(address: Address, network: Network) async throws -> JettonInfo {
        return try await apiProvider.api(network).resolveJetton(address: address)
    }
}
