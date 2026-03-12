import Foundation
import KeeperCore

enum StonfiSwapHandlerResult {
    case success(String)
    case failed(Int)

    init(_ result: SendTransactionSignResult) {
        switch result {
        case let .response(data):
            self = .success(data)
        case let .error(error):
            self = .failed(error.rawValue)
        }
    }
}

protocol StonfiSwapMessageHandler {
    func handleFunctionInvokeMessage(_ message: StonfiSwapFunctionInvokeMessage, completion: @escaping (StonfiSwapHandlerResult) -> Void)
}

final class DefaultStonfiSwapMessageHandler: StonfiSwapMessageHandler {
    var send: ((SignRawRequest, @escaping (SendTransactionSignResult) -> Void) -> Void)?
    var close: (() -> Void)?

    func handleFunctionInvokeMessage(_ message: StonfiSwapFunctionInvokeMessage, completion: @escaping (StonfiSwapHandlerResult) -> Void) {
        switch message.type {
        case .close:
            close?()
        case .sendTransaction:
            guard !message.args.isEmpty,
                  let data = try? JSONSerialization.data(withJSONObject: message.args),
                  let request = try? JSONDecoder().decode(StonfiSwapSignRawRequest.self, from: data)
            else {
                completion(.failed(TonConnect.SendResponseError.ErrorCode.badRequest.rawValue))
                return
            }

            let sendCompletion: ((SendTransactionSignResult) -> Void) = { result in
                completion(StonfiSwapHandlerResult(result))
            }
            send?(request.signRawRequest, sendCompletion)
        }
    }
}

private struct StonfiSwapSignRawRequest: Decodable {
    enum Error: Swift.Error {
        case noSignRawRequest
    }

    let signRawRequest: SignRawRequest
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var requests = [SignRawRequest]()
        while !container.isAtEnd {
            let request = try container.decode(SignRawRequest.self)
            requests.append(request)
        }
        guard requests.count > 0 else {
            throw Error.noSignRawRequest
        }
        signRawRequest = requests[0]
    }
}
