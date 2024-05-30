import TonSwift

protocol SearchTokensService {
    func getJettons(accountAddress: Address) async throws -> [JettonInfo]
}

final class SearchTokensServiceImplementation: SearchTokensService {
    private let api: API
    
    init(api: API) {
        self.api = api
    }
    
    func getJettons(accountAddress: Address) async throws -> [JettonInfo] {
        let jettons = try await api.getJettons(address: accountAddress)
        return jettons
    }
}
