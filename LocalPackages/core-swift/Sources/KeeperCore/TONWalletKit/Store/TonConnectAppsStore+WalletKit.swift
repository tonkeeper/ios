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
        let sessionCrypto = try TonConnectSessionCrypto()
        let encrypted = try tonConnectService.encryptSuccessResponse(
            connectEventSuccessResponse,
            parameters: parameters,
            sessionCrypto: sessionCrypto
        )
        try await tonConnectService.confirmConnectionRequest(
            body: encrypted,
            sessionCrypto: sessionCrypto,
            parameters: parameters
        )
        let responses = connectEventSuccessResponse.payload.items.compactMap {
            $0.connectionResponse()
        }
        try await request.approve(walletId: wallet.walletKitIdentifier, response: responses.first)
        await MainActor.run {
            notifyObservers(event: .didUpdateApps)
        }
    }

    func connectWalletKitBridgeDapp(
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
        try await request.approve(walletId: wallet.walletKitIdentifier, response: responses.first)
        await MainActor.run {
            notifyObservers(event: .didUpdateApps)
        }
    }
}
