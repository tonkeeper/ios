import Foundation
import TonSwift

public enum TonConnectResponseBuilder {
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

    public static func buildSendTransactionResponseSuccess(
        sessionCrypto: TonConnectSessionCrypto,
        boc: String,
        id: String,
        clientId: String
    ) throws -> String {
        let response = TonConnect.SendResponse.success(
            .init(
                result: boc,
                id: id
            )
        )
        let transactionResponseData = try JSONEncoder().encode(response)
        guard let receiverPublicKey = Data(hex: clientId) else { return "" }

        let encryptedTransactionResponse = try sessionCrypto.encrypt(
            message: transactionResponseData,
            receiverPublicKey: receiverPublicKey
        )

        return encryptedTransactionResponse.base64EncodedString()
    }

    public static func buildSignDataResponseSuccess(
        sessionCrypto: TonConnectSessionCrypto,
        signed: SignedDataResult,
        id: String,
        clientId: String
    ) throws -> String {
        let response = TonConnect.SendResponse.success(
            .init(
                result: signed,
                id: id
            )
        )
        let transactionResponseData = try JSONEncoder().encode(response)
        guard let receiverPublicKey = Data(hex: clientId) else { return "" }

        let encryptedTransactionResponse = try sessionCrypto.encrypt(
            message: transactionResponseData,
            receiverPublicKey: receiverPublicKey
        )

        return encryptedTransactionResponse.base64EncodedString()
    }

    static func buildSendTransactionResponseError(
        sessionCrypto: TonConnectSessionCrypto,
        errorCode: TonConnect.SendResponseError.ErrorCode,
        id: String,
        clientId: String
    ) throws -> String {
        let response = TonConnect.SendResponse.error(
            .init(
                id: id,
                error: .init(
                    code: errorCode,
                    message: ""
                )
            )
        )
        let transactionResponseData = try JSONEncoder().encode(response)
        guard let receiverPublicKey = Data(hex: clientId) else { return "" }

        let encryptedTransactionResponse = try sessionCrypto.encrypt(
            message: transactionResponseData,
            receiverPublicKey: receiverPublicKey
        )

        return encryptedTransactionResponse.base64EncodedString()
    }
}
