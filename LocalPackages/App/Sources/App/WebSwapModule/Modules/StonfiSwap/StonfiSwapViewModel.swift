import Foundation
import KeeperCore

protocol StonfiSwapViewModel: AnyObject {
  var didOpen: ((URL?, String?) -> Void)? { get set }
  var injectHandler: ((String) -> Void)? { get set }
  var jsInjection: String? { get }
  
  func viewDidLoad()
  func didLoadInitialRequest()
  func didReceiveMessage(body: Any)
}

final class StonfiSwapViewModelImplementation: StonfiSwapViewModel {
  var didOpen: ((URL?, String?) -> Void)?
  var injectHandler: ((String) -> Void)?
  
  func viewDidLoad() {
    Task {
      guard let stonfiUrl = try? await configurationStore.getConfiguration().stonfiUrl else {
        return
      }
      await MainActor.run {
        didOpen?(stonfiUrl, nil)
      }
    }
  }
  
  func didLoadInitialRequest() {
    
  }
  
  func didReceiveMessage(body: Any) {
    guard let string = body as? String,
          let data = string.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let type = json["type"] as? String,
          let messageType = StonfiSwapBridgeMessageType(rawValue: type),
          messageType == .invokeRnFunc,
          let name = json["name"] as? String,
          let functionType = StonfiSwapBridgeFunctionType(rawValue: name),
          let invocationId = json["invocationId"] as? String,
          let args = json["args"] as? [Any] else {
      return
    }
    
    let message = StonfiSwapFunctionInvokeMessage(
      type: functionType,
      invocationId: invocationId,
      args: args
    )
    
    messageHandler.handleFunctionInvokeMessage(message) { [weak self] result in
      switch result {
      case .success(let string):
        let response = StonfiSwapBridgeResponse(
          invocationId: message.invocationId,
          status: .fulfilled,
          data: .data(string)
        )
        self?.sendResponse(response)
      case .failed(let error):
        let response = StonfiSwapBridgeResponse(
          invocationId: message.invocationId,
          status: .rejected,
          data: .error(error)
        )
        self?.sendResponse(response)
      }
    }
  }

  private let walletsStore: WalletsStore
  private let configurationStore: ConfigurationStore
  private let messageHandler: StonfiSwapMessageHandler
  
  init(walletsStore: WalletsStore,
       configurationStore: ConfigurationStore,
       messageHandler: StonfiSwapMessageHandler) {
    self.walletsStore = walletsStore
    self.configurationStore = configurationStore
    self.messageHandler = messageHandler
  }
  
  private func sendResponse(_ response: StonfiSwapBridgeResponse) {
    guard let responseJson = response.json else { return }
    let js = """
    (function() {
        window.dispatchEvent(new MessageEvent('message', {
            data: \(responseJson)
        }));
    })();
    """
    injectHandler?(js)
  }
  
  var jsInjection: String? {
    guard let info = try? Info(address: walletsStore.getActiveWallet().address.toRaw()),
          let infoData = try? JSONEncoder().encode(info),
          var infoString = String(data: infoData, encoding: .utf8) else { return nil }
    infoString = String(describing: infoString).replacingOccurrences(of: "\\", with: "")
    return """
            (() => {
                            if (!window.\(String.windowKey)) {
                                window.rnPromises = {};
                                window.rnEventListeners = [];
                                window.invokeRnFunc = (name, args, resolve, reject) => {
                                    const invocationId = btoa(Math.random()).substring(0, 12);
                                    const timeoutMs = null;
                                    const timeoutId = timeoutMs ? setTimeout(() => reject(new Error('bridge timeout for function with name: '+name+'')), timeoutMs) : null;
                                    window.rnPromises[invocationId] = { resolve, reject, timeoutId }
                                    window.webkit.messageHandlers.swap.postMessage(JSON.stringify({
                                        type: '\(StonfiSwapBridgeMessageType.invokeRnFunc.rawValue)',
                                        invocationId: invocationId,
                                        name,
                                        args,
                                    }));
                                };
                                
                                window.addEventListener('message', ({ data }) => {
                                    try {
                                        const message = data;
                                        console.log('message bridge', JSON.stringify(message));
                                        if (message.type === '\(StonfiSwapBridgeMessageType.functionResponse.rawValue)') {
                                            const promise = window.rnPromises[message.invocationId];
                                            
                                            if (!promise) {
                                                return;
                                            }
                                            
                                            if (promise.timeoutId) {
                                                clearTimeout(promise.timeoutId);
                                            }
                                            
                                            if (message.status === 'fulfilled') {
                                                promise.resolve(JSON.parse(message.data));
                                            } else {
                                                promise.reject(new Error(message.data));
                                            }
                                            
                                            delete window.rnPromises[message.invocationId];
                                        }
                                        
                                        if (message.type === '\(StonfiSwapBridgeMessageType.event.rawValue)') {
                                            window.rnEventListeners.forEach((listener) => listener(message.event));
                                        }
                                    } catch { }
                                });
                            }
                            
                            const listen = (cb) => {
                                window.rnEventListeners.push(cb);
                                return () => {
                                    const index = window.rnEventListeners.indexOf(cb);
                                    if (index > -1) {
                                        window.rnEventListeners.splice(index, 1);
                                    }
                                };
                            };
                            
                                                                        window.\(String.windowKey) = Object.assign(\(infoString),{
                                        close: (...args) => {
                                            return new Promise((resolve, reject) => window.invokeRnFunc('close', args, resolve, reject))
                                        }
                                    ,
                                        sendTransaction: (...args) => {
                                            return new Promise((resolve, reject) => window.invokeRnFunc('sendTransaction', args, resolve, reject))
                                        }
                                     },{ listen });
                                        })();
    """
  }
}

private struct Info: Encodable {
  let address: String
}

struct StonfiSwapFunctionInvokeMessage {
  let type: StonfiSwapBridgeFunctionType
  let invocationId: String
  let args: [Any]
}

struct StonfiSwapBridgeResponse {
  enum Status: String {
    case fulfilled
    case rejected
  }
  
  enum Data {
    case data(String)
    case error(Int)
  }

  let invocationId: String
  let status: Status
  let data: Data
  
  var json: String? {
    var dictionary: [String: Any] = ["invocationId": invocationId,
                                     "status": status.rawValue, 
                                     "type": "functionResponse"]
    switch data {
    case .data(let data):
      dictionary["data"] = data
    case .error(let error):
      dictionary["data"] = error
    }
    guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
    let dataString = String(data: data, encoding: .utf8) else { return nil }
    return dataString
  }
}

enum StonfiSwapBridgeMessageType: String, Codable {
  case invokeRnFunc
  case functionResponse
  case event
}

enum StonfiSwapBridgeFunctionType: String, Codable {
  case sendTransaction
  case close
}

private extension String {
  static let windowKey = "tonkeeperStonfi"
}
