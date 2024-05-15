import Foundation
import KeeperCore

enum DappMessageHandlerResult {
  case success(Data)
  case failed(Int)
  
  init(_ result: TonConnectAppsStore.ConnectResult) {
    switch result {
    case .response(let data):
      self = .success(data)
    case .error(let error):
      self = .failed(error.rawValue)
    }
  }
  
  init(_ result: TonConnectAppsStore.SendTransactionResult) {
    switch result {
    case .response(let data):
      self = .success(data)
    case .error(let error):
      self = .failed(error.rawValue)
    }
  }
}

protocol DappMessageHandler {
  func handleFunctionInvokeMessage(_ message: DappFunctionInvokeMessage, dapp: Dapp, completion: @escaping (DappMessageHandlerResult) -> Void)
  func reconnectIfNeeded(dapp: Dapp, completion: @escaping (DappMessageHandlerResult) -> Void)
}

final class DefaultDappMessageHandler: DappMessageHandler {
  var connect: ((Int, TonConnectRequestPayload, @escaping (TonConnectAppsStore.ConnectResult) -> Void) -> Void)?
  var reconnect: ((Dapp, @escaping (TonConnectAppsStore.ConnectResult) -> Void) -> Void)?
  var disconnect: ((Dapp) -> Void)?
  var send: ((Dapp, TonConnect.AppRequest, @escaping (TonConnectAppsStore.SendTransactionResult) -> Void) -> Void)?
  
  func handleFunctionInvokeMessage(_ message: DappFunctionInvokeMessage, dapp: Dapp, completion: @escaping (DappMessageHandlerResult) -> Void) {
    switch message.type {
    case .connect:
      guard message.args.count >= 2,
            let protocolVersion = message.args[0] as? Int,
            let connectPayload = message.args[1] as? [String: Any],
            let data = try? JSONSerialization.data(withJSONObject: connectPayload),
            let payload = try? JSONDecoder().decode(TonConnectRequestPayload.self, from: data) else {
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
    case .send:
      guard !message.args.isEmpty,
            let data = try? JSONSerialization.data(withJSONObject: message.args[0]),
            let request = try? JSONDecoder().decode(TonConnect.AppRequest.self, from: data)
      else {
        completion(.failed(TonConnect.SendTransactionResponseError.ErrorCode.badRequest.rawValue))
        return
      }
      let sendCompletion: ((TonConnectAppsStore.SendTransactionResult) -> Void) = { result in
        completion(DappMessageHandlerResult(result))
      }
      send?(dapp, request, sendCompletion)
    case .disconnect:
      disconnect?(dapp)
    }
  }
  
  func reconnectIfNeeded(dapp: Dapp, completion: @escaping (DappMessageHandlerResult) -> Void) {
    let reconnectCompletion: ((TonConnectAppsStore.ConnectResult) -> Void) = { result in
      completion(DappMessageHandlerResult(result))
    }
    reconnect?(dapp, reconnectCompletion)
  }
}
