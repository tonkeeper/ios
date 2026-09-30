import Foundation
import KeeperCore

enum DappMessageHandlerResult {
    case success(Data)
    case failed(Int)
    case rejected(code: Int, message: String)

    init(_ result: TonConnectAppsStore.ConnectResult) {
        switch result {
        case let .response(data):
            self = .success(data)
        case let .error(error):
            self = .failed(error.rawValue)
        }
    }

    init(_ result: TonConnectAppsStore.FetchResult) {
        switch result {
        case let .response(data):
            self = .success(data)
        case let .error(error):
            self = .failed(error.rawValue)
        }
    }

    init(_ result: TonConnectAppsStore.SendResult) {
        switch result {
        case let .response(data):
            self = .success(data)
        case let .error(error):
            self = .failed(error.rawValue)
        }
    }
}

protocol DappMessageHandler {
    func handleFunctionInvokeMessage(_ message: DappFunctionInvokeMessage, dapp: Dapp, completion: @escaping (DappMessageHandlerResult) -> Void)
    func reconnectIfNeeded(dapp: Dapp, completion: @escaping (DappMessageHandlerResult) -> Void)
}

final class DefaultDappMessageHandler: DappMessageHandler {
    private static let voidResponse = Data("{}".utf8)

    var connect: ((Int, TonConnectRequestPayload, @escaping (TonConnectAppsStore.ConnectResult) -> Void) -> Void)?
    var reconnect: ((Dapp, @escaping (TonConnectAppsStore.ConnectResult) -> Void) -> Void)?
    var disconnect: ((Dapp) -> Void)?
    var sendTransaction: ((Dapp, TonConnect.SendTransactionRequest, @escaping (TonConnectAppsStore.SendResult) -> Void) -> Void)?
    var fetch: ((String, [String: Any]?, @escaping (TonConnectAppsStore.FetchResult) -> Void) -> Void)?
    var signData: ((Dapp, TonConnect.SignDataRequest, @escaping (TonConnectAppsStore.SendResult) -> Void) -> Void)?
    var toggleLandscape: ((Bool) -> Void)?
    var navigateBack: (() -> Void)?
    var track: ((String, [String: Any]) -> Void)?

    func handleFunctionInvokeMessage(_ message: DappFunctionInvokeMessage, dapp: Dapp, completion: @escaping (DappMessageHandlerResult) -> Void) {
        switch message.type {
        case .connect:
            guard message.args.count >= 2,
                  let protocolVersion = message.args[0] as? Int,
                  let connectPayload = message.args[1] as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: connectPayload),
                  let payload = try? JSONDecoder().decode(TonConnectRequestPayload.self, from: data)
            else {
                completion(.failed(TonConnect.ConnectEventError.Error.badRequest.rawValue))
                return
            }

            let connectCompletion: ((TonConnectAppsStore.ConnectResult) -> Void) = { result in
                completion(DappMessageHandlerResult(result))
            }

            connect?(protocolVersion, payload, connectCompletion)
        case .restoreConnection:
            let reconnectCompletion: ((TonConnectAppsStore.ConnectResult) -> Void) = { result in
                completion(DappMessageHandlerResult(result))
            }
            reconnect?(dapp, reconnectCompletion)
        case .tonapiFetch:
            guard message.args.count >= 1,
                  let url = message.args[0] as? String,
                  let params = message.args[1] as? [String: Any]?
            else {
                completion(.failed(TonConnect.FetchEventError.ErrorCode.unknownError.rawValue))
                return
            }
            let fetchCompletion: ((TonConnectAppsStore.FetchResult) -> Void) = { result in
                completion(DappMessageHandlerResult(result))
            }
            fetch?(url, params, fetchCompletion)
        case .send:
            guard !message.args.isEmpty,
                  let data = try? JSONSerialization.data(withJSONObject: message.args[0]),
                  let request = try? JSONDecoder().decode(TonConnect.AppRequest.self, from: data)
            else {
                completion(.failed(TonConnect.SendResponseError.ErrorCode.badRequest.rawValue))
                return
            }

            let sendCompletion: ((TonConnectAppsStore.SendResult) -> Void) = { result in
                completion(DappMessageHandlerResult(result))
            }

            switch request {
            case let .sendTransaction(sendTransactionRequest):
                sendTransaction?(dapp, sendTransactionRequest, sendCompletion)
            case let .signData(signDataRequest):
                signData?(dapp, signDataRequest, sendCompletion)
            case let .disconnect(disconnectRequest):
                disconnect?(dapp)
                let response = TonConnect.SendResponse.success(.init(id: disconnectRequest.id))
                if let data = try? JSONEncoder().encode(response) {
                    sendCompletion(.response(data))
                } else {
                    sendCompletion(.error(.unknownError))
                }
            }
        case .lockOrientation:
            toggleLandscape?(false)
            completion(.success(Self.voidResponse))
        case .unlockOrientation:
            toggleLandscape?(true)
            completion(.success(Self.voidResponse))
        case .disconnect:
            disconnect?(dapp)
            completion(.success(Self.voidResponse))
        case .uiNavigateBack:
            navigateBack?()
            completion(.success(Self.voidResponse))
        case .analyticsTrack:
            let params = message.args.first as? [String: Any]
            guard let event = params?["event"] as? String, event.contains(where: { !$0.isWhitespace }) else {
                completion(
                    .rejected(
                        code: DappNativeBridge.ErrorCode.invalidParams.rawValue,
                        message: DappNativeBridge.ErrorMessage.missingEvent
                    )
                )
                return
            }
            track?(event, DappNativeBridge.trackParams(params?["params"] as? [String: Any]))
            completion(.success(Self.voidResponse))
        }
    }

    func reconnectIfNeeded(dapp: Dapp, completion: @escaping (DappMessageHandlerResult) -> Void) {
        let reconnectCompletion: ((TonConnectAppsStore.ConnectResult) -> Void) = { result in
            completion(DappMessageHandlerResult(result))
        }
        reconnect?(dapp, reconnectCompletion)
    }
}
