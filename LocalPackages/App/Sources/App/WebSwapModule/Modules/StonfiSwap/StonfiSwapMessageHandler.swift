import Foundation
import KeeperCore

enum StonfiSwapHandlerResult {
  case success(String)
  case failed(Int)
  
  init(_ result: SendTransactionSignResult) {
    switch result {
    case .response(let data):
      self = .success(data)
    case .error(let error):
      self = .failed(error.rawValue)
    }
  }
}

protocol StonfiSwapMessageHandler {
  func handleFunctionInvokeMessage(_ message: StonfiSwapFunctionInvokeMessage, completion: @escaping (StonfiSwapHandlerResult) -> Void)
}

final class DefaultStonfiSwapMessageHandler: StonfiSwapMessageHandler {
  var send: ((SendTransactionSignRequest, @escaping (SendTransactionSignResult) -> Void) -> Void)?
  var close: (() -> Void)?
  
  func handleFunctionInvokeMessage(_ message: StonfiSwapFunctionInvokeMessage, completion: @escaping (StonfiSwapHandlerResult) -> Void) {
    switch message.type {
    case .close:
      close?()
    case .sendTransaction:
      guard !message.args.isEmpty,
            let data = try? JSONSerialization.data(withJSONObject: message.args),
            let request = try? JSONDecoder().decode(SendTransactionSignRequest.self, from: data)
      else {
        completion(.failed(TonConnect.SendTransactionResponseError.ErrorCode.badRequest.rawValue))
        return
      }
      
      let sendCompletion: ((SendTransactionSignResult) -> Void) = { result in
        completion(StonfiSwapHandlerResult(result))
      }
      send?(request, sendCompletion)
    }
  }
}
