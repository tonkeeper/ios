import Foundation
import KeeperCoreComponents
import TonSwift

enum TonConnectResponseBuilder {
    static func buildReconnectConnectEventSuccessResponse(
        wallet: Wallet,
        keeperVersion: String,
        manifest: TonConnectManifest
    ) throws -> TonConnect.ConnectEventSuccess {
        let address = try wallet.address

        let replyItems = try [TonConnect.ConnectItemReply.tonAddress(
            .init(
                address: address,
                network: wallet.identity.network,
                publicKey: wallet.publicKey,
                walletStateInit: wallet.stateInit
            )
        )]

        return try TonConnect.ConnectEventSuccess(
            payload: .init(
                items: replyItems,
                device: .init(maxMessages: wallet.contract.maxMessages, appVersion: keeperVersion)
            )
        )
    }

    // Build connect response with private key provided

    static func buildConnectEventSuccesResponse(
        requestPayloadItems: [TonConnectRequestPayload.Item],
        wallet: Wallet,
        keeperVersion: String,
        manifest: TonConnectManifest,
        signTonProof: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply
    ) async throws -> TonConnect.ConnectEventSuccess {
        let address = try wallet.address
        var replyItems = [TonConnect.ConnectItemReply]()

        for item in requestPayloadItems {
            switch item {
            case .tonAddress:
                let reply = try TonConnect.ConnectItemReply.tonAddress(
                    .init(
                        address: address,
                        network: wallet.identity.network,
                        publicKey: wallet.publicKey,
                        walletStateInit: wallet.stateInit
                    )
                )
                replyItems.append(reply)

            case let .tonProof(payload):
                let reply = try await signTonProof(payload)
                replyItems.append(reply)

            case .unknown:
                continue
            }
        }

        return try TonConnect.ConnectEventSuccess(
            payload: .init(items: replyItems, device: .init(maxMessages: wallet.contract.maxMessages, appVersion: keeperVersion))
        )
    }

    static func buildSendTransactionResponseSuccess(
        sessionCrypto: TonConnectSessionCrypto,
        boc: String,
        id: String,
        clientId: String
    ) throws -> String {
        try encrypt(
            .success(.init(result: boc, id: id)),
            sessionCrypto: sessionCrypto,
            clientId: clientId
        )
    }

    static func buildSignDataResponseSuccess(
        sessionCrypto: TonConnectSessionCrypto,
        signed: SignedDataResult,
        id: String,
        clientId: String
    ) throws -> String {
        try encrypt(
            .success(.init(result: signed, id: id)),
            sessionCrypto: sessionCrypto,
            clientId: clientId
        )
    }

    static func buildDisconnectResponseSuccess(
        sessionCrypto: TonConnectSessionCrypto,
        id: String,
        clientId: String
    ) throws -> String {
        try encrypt(
            .success(.init(id: id)),
            sessionCrypto: sessionCrypto,
            clientId: clientId
        )
    }

    static func buildSendTransactionResponseError(
        sessionCrypto: TonConnectSessionCrypto,
        errorCode: TonConnect.SendResponseError.ErrorCode,
        id: String,
        clientId: String
    ) throws -> String {
        try encrypt(
            .error(.init(id: id, error: .init(code: errorCode, message: ""))),
            sessionCrypto: sessionCrypto,
            clientId: clientId
        )
    }

    private static func encrypt(
        _ response: TonConnect.SendResponse,
        sessionCrypto: TonConnectSessionCrypto,
        clientId: String
    ) throws -> String {
        let responseData = try JSONEncoder().encode(response)
        guard let receiverPublicKey = Data(strictHex: clientId) else { return "" }

        return try sessionCrypto.encrypt(
            message: responseData,
            receiverPublicKey: receiverPublicKey
        ).base64EncodedString()
    }
}
