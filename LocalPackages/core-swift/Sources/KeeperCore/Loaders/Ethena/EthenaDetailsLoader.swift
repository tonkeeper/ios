import Foundation

public actor EthenaStakingLoader {
    enum State {
        case idle
        case loading(Task<EthenaStakingResponse, Error>)
        case response(EthenaStakingResponse)
    }

    private var state: State = .idle

    private let wallet: Wallet
    private let api: TonkeeperAPI

    init(
        wallet: Wallet,
        api: TonkeeperAPI
    ) {
        self.wallet = wallet
        self.api = api
    }

    public func getResponse(reload: Bool) async throws -> EthenaStakingResponse {
        switch state {
        case .idle:
            let task = Task<EthenaStakingResponse, Error> {
                let response = try await api.getEthenaStakingDetails(
                    address: wallet.address.toFriendly(testOnly: wallet.network == .testnet, bounceable: false).toString()
                )
                self.state = .response(response)
                return response
            }
            return try await task.value
        case let .loading(task):
            return try await task.value
        case let .response(ethenaStakingResponse):
            if reload {
                let task = Task<EthenaStakingResponse, Error> {
                    let response = try await api.getEthenaStakingDetails(
                        address: wallet.address.toFriendly(testOnly: wallet.network == .testnet, bounceable: false).toString()
                    )
                    self.state = .response(response)
                    return response
                }
                return try await task.value
            }
            return ethenaStakingResponse
        }
    }
}
