import Foundation
import KeeperCore

protocol DappViewModel: AnyObject {
  var didOpenApp: ((URL?, String?) -> Void)? { get set }
  var injectHandler: ((String, (() -> Void)?) -> Void)? { get set }
  
  func viewDidLoad()
  func didLoadInitialRequest()
  func didReceiveMessage(body: Any)
  func reconnectIfNeeded()
}

final class DappViewModelImplementation: DappViewModel {
  var didOpenApp: ((URL?, String?) -> Void)?
  var injectHandler: ((String, (() -> Void)?) -> Void)?
  
  func viewDidLoad() {
    didOpenApp?(app.url, app.name)
  }
  
  func didLoadInitialRequest() {
    guard let jsInjection = self.jsInjection else { return }
    let completion: () -> Void = { [weak self] in
      self?.reconnectIfNeeded()
    }
    injectHandler?(jsInjection, completion)
  }
  
  func reconnectIfNeeded() {
    messageHandler.reconnectIfNeeded(app: app) { [weak self] result in
      switch result {
      case .success(let data):
        guard let string = String(data: data, encoding: .utf8) else {
          return
        }
        let response = DappBridgeResponse(
          invocationId: "",
          status: .fulfilled,
          data: .data(string)
        )
        self?.sendResponse(response)
      case .failed:
        break
      }
    }
  }
  
  func didReceiveMessage(body: Any) {
    print("didReceiveMessage\(body)")
    guard let string = body as? String,
          let data = string.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let type = json["type"] as? String,
          let messageType = DappBridgeMessageType(rawValue: type),
          messageType == .invokeRnFunc,
          let name = json["name"] as? String,
          let functionType = DappBridgeFunctionType(rawValue: name),
          let invocationId = json["invocationId"] as? String,
          let args = json["args"] as? [Any] else {
      return
    }
    
    let message = DappFunctionInvokeMessage(
      type: functionType,
      invocationId: invocationId,
      args: args
    )
    
    messageHandler.handleFunctionInvokeMessage(message, app: app) { [weak self] result in
      switch result {
      case .success(let data):
        guard let string = String(data: data, encoding: .utf8) else {
          return
        }
        let response = DappBridgeResponse(
          invocationId: message.invocationId,
          status: .fulfilled,
          data: .data(string)
        )
        self?.sendResponse(response)
      case .failed(let error):
        let response = DappBridgeResponse(
          invocationId: message.invocationId,
          status: .rejected,
          data: .error(error)
        )
        self?.sendResponse(response)
      }
    }
  }
  
  private let app: PopularApp
  private let messageHandler: DappMessageHandler
  
  init(app: PopularApp,
       messageHandler: DappMessageHandler) {
    self.app = app
    self.messageHandler = messageHandler
  }
  
  private func sendResponse(_ response: DappBridgeResponse) {
    guard let responseJson = response.json else { return }
    let js = """
    (function() {
        window.dispatchEvent(new MessageEvent('message', {
            data: \(responseJson)
        }));
    })();
    """
    injectHandler?(js, nil)
  }
}

private struct Info: Encodable {
  let isWalletBrowser: Bool
  let deviceInfo: TonConnect.DeviceInfo
  let protocolVersion: Int
}

struct DappFunctionInvokeMessage {
  let type: DappBridgeFunctionType
  let invocationId: String
  let args: [Any]
}

struct DappBridgeResponse {
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

enum DappBridgeMessageType: String, Codable {
  case invokeRnFunc
  case functionResponse
  case event
}

enum DappBridgeFunctionType: String, Codable {
  case send
  case connect
  case restoreConnection
  case disconnect
}

private extension DappViewModel {
  var jsInjection: String? {
    let deviceInfo = TonConnect.DeviceInfo()
    let info = Info(
      isWalletBrowser: true,
      deviceInfo: deviceInfo,
      protocolVersion: 2
    )
    guard let infoData = try? JSONEncoder().encode(info),
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
                                    window.webkit.messageHandlers.dapp.postMessage(JSON.stringify({
                                        type: '\(DappBridgeMessageType.invokeRnFunc.rawValue)',
                                        invocationId: invocationId,
                                        name,
                                        args,
                                    }));
                                };
                                
                                window.addEventListener('message', ({ data }) => {
                                    try {
                                        const message = data;
                                        console.log('message bridge', JSON.stringify(message));
                                        if (message.type === '\(DappBridgeMessageType.functionResponse.rawValue)') {
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
                                        
                                        if (message.type === '\(DappBridgeMessageType.event.rawValue)') {
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
                            
                            window.\(String.windowKey) = {
                                tonconnect: Object.assign(\(infoString),{ send: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('send', args, resolve, reject))},connect: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('connect', args, resolve, reject))},restoreConnection: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('restoreConnection', args, resolve, reject))},disconnect: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('disconnect', args, resolve, reject))} },{ listen }),
                            }
                        })();
    """
  }
}

private extension String {
  static let windowKey = "tonkeeper"
}
