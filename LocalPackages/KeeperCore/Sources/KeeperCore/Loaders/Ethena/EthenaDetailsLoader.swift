import Foundation

@frozen public enum EthenaStakingLoaderError: Swift.Error {
    case walletUnavailable
}

public actor EthenaStakingLoader {
    enum State {
        case idle
        case loading(Task<EthenaStakingResponse, Error>)
        case response(EthenaStakingResponse)
    }

    private var state: State = .idle

    private let walletId: String
    private let walletsStore: WalletsStore
    private let api: TonkeeperAPI

    init(
        walletId: String,
        walletsStore: WalletsStore,
        api: TonkeeperAPI
    ) {
        self.walletId = walletId
        self.walletsStore = walletsStore
        self.api = api
    }

    public func getResponse(reload: Bool) async throws -> EthenaStakingResponse {
        switch state {
        case .idle:
            return try await fetch().value
        case let .loading(task):
            return try await task.value
        case let .response(ethenaStakingResponse):
            if reload {
                return try await fetch().value
            }
            return ethenaStakingResponse
        }
    }

    private func fetch() -> Task<EthenaStakingResponse, Error> {
        Task<EthenaStakingResponse, Error> {
            // The loader is cached per wallet id and outlives the wallet's enrichment, so the
            // multichain wallet id has to come from the store.
            guard let wallet = walletsStore.getWallet(id: walletId) else {
                throw EthenaStakingLoaderError.walletUnavailable
            }
            let response = try await api.getEthenaStakingDetails(
                address: wallet.address.toFriendly(testOnly: wallet.network == .testnet, bounceable: false).toString(),
                walletId: wallet.multichainWalletState?.walletId
            )
            self.state = .response(response)
            return response
        }
    }
}
