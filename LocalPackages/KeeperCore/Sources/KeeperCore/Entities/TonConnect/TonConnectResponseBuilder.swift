import Foundation
import KeeperCoreComponents
import TonSwift

enum TonConnectResponseBuilder {
    static func buildReconnectConnectEventSuccessResponse(
        wallet: Wallet,
        keeperVersion: String,
        manifest: TonConnectManifest,
        isSignMessageSupported: Bool
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
                device: .init(
                    maxMessages: wallet.contract.maxMessages,
                    appVersion: keeperVersion,
                    isSignMessageSupported: isSignMessageSupported,
                    isSignDataSupported: wallet.isTonConnectSignDataAvailable
                )
            )
        )
    }

    // Build connect response with private key provided

    static func buildConnectEventSuccesResponse(
        requestPayloadItems: [TonConnectRequestPayload.Item],
        wallet: Wallet,
        keeperVersion: String,
        manifest: TonConnectManifest,
        isSignMessageSupported: Bool,
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
            payload: .init(
                items: replyItems,
                device: .init(
                    maxMessages: wallet.contract.maxMessages,
                    appVersion: keeperVersion,
                    isSignMessageSupported: isSignMessageSupported,
                    isSignDataSupported: wallet.isTonConnectSignDataAvailable
                )
            )
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

    static func buildSignMessageResponseSuccess(
        sessionCrypto: TonConnectSessionCrypto,
        internalBoc: String,
        id: String,
        clientId: String
    ) throws -> String {
        try encrypt(
            .success(.init(result: TonConnect.SignMessageResult(internalBoc: internalBoc), id: id)),
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
        message: String = "",
        id: String,
        clientId: String
    ) throws -> String {
        try encrypt(
            .error(.init(id: id, error: .init(code: errorCode, message: message))),
            sessionCrypto: sessionCrypto,
            clientId: clientId
        )
    }

    static func buildDisconnectEvent(
        sessionCrypto: TonConnectSessionCrypto,
        clientId: String
    ) throws -> String {
        try encrypt(
            JSONEncoder().encode(TonConnect.DisconnectEvent()),
            sessionCrypto: sessionCrypto,
            clientId: clientId
        )
    }

    private static func encrypt(
        _ response: TonConnect.SendResponse,
        sessionCrypto: TonConnectSessionCrypto,
        clientId: String
    ) throws -> String {
        try encrypt(
            JSONEncoder().encode(response),
            sessionCrypto: sessionCrypto,
            clientId: clientId
        )
    }

    private static func encrypt(
        _ message: Data,
        sessionCrypto: TonConnectSessionCrypto,
        clientId: String
    ) throws -> String {
        guard let receiverPublicKey = Data(strictHex: clientId) else { return "" }

        return try sessionCrypto.encrypt(
            message: message,
            receiverPublicKey: receiverPublicKey
        ).base64EncodedString()
    }
}
