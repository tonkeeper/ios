import Foundation
import TonSwift

public final class SwapSearchTokenController {
    
    public var didUpdateModel: (([JettonInfo]) -> Void)?
    public var didGetError: ((Error) -> Void)?
    
    public  let wallet: Wallet
    private let searchTokensService: SearchTokensService
    
    init(wallet: Wallet,
         searchTokensService: SearchTokensService) {
        self.wallet = wallet
        self.searchTokensService = searchTokensService
    }
    
    public func start() async {
        do {
            let model = try await buildInitialModel()
            await MainActor.run {
                didUpdateModel?(model)
            }
        } catch {
            didGetError?(error)
        }
    }
    
}

private extension SwapSearchTokenController {
    func buildInitialModel() async throws -> [JettonInfo] {
        try await buildModel()
    }
    
    func buildModel() async throws -> [JettonInfo] {
        let accountAddress = try wallet.address
        let jettons = try await searchTokensService.getJettons(accountAddress: accountAddress)
        return jettons
    }
}
