import Foundation
import TONWalletKit

public extension TonConnectAppsStore {
    func connectWalletKit(
        wallet: Wallet,
        parameters: TonConnectParameters,
        manifest: TonConnectManifest,
        signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply,
        keeperVersion: String,
        request: TONWalletConnectionRequest
    ) async throws {
        let connectEventSuccessResponse = try await tonConnectService.buildConnectEventSuccessResponse(
            wallet: wallet,
            parameters: parameters,
            manifest: manifest,
            signTonProofHandler: signTonProofHandler,
            keeperVersion: keeperVersion
        )
        let responses = connectEventSuccessResponse.payload.items.compactMap {
            $0.connectionResponse()
        }
        setPendingConnectionSource(
            parameters.source,
            clientId: parameters.clientId,
            manifestURL: parameters.requestPayload.manifestUrl
        )
        try await request.approve(walletId: wallet.walletKitIdentifier, response: responses.first)
        await MainActor.run {
            notifyObservers(event: .didUpdateApps)
        }
    }
}
