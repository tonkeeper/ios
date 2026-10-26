import Foundation
import TKLogging

enum EVMProviderBridge {
    enum ErrorCode: Int {
        case userRejected = 4001
        case unauthorized = 4100
        case unsupportedMethod = 4200
        case unrecognizedChain = 4902
        case internalError = -32603
    }

    enum Event: String {
        case accountsChanged = "ethereum.accountsChanged"
        case chainChanged = "ethereum.chainChanged"
    }

    enum ErrorMessage {
        static let malformedRequest = "Malformed request"
        static let unsupportedMethod = "Unsupported method"
        static let unrecognizedChain = "Unrecognized chain id"
        static let noAccount = "No EVM account available"
        static let userRejected = "User rejected the request"
        static let signingFailed = "Failed to sign the request"
    }

    static let requestFunctionName = "eth.request"

    static func injection(address: String, chainIdHex: String) -> String {
        """
        if (!window.ethereum) {
            const listeners = {};
            window.ethereum = {
                chainId: '\(chainIdHex)',
                networkVersion: '\(chainIdHex)',
                selectedAddress: '\(address)',
                request: ({ method, params }) => new Promise((resolve, reject) => {
                    window.invokeRnFunc('\(requestFunctionName)', [{ method, params: params || [] }], resolve, reject);
                }),
                on: (event, handler) => {
                    (listeners[event] || (listeners[event] = [])).push(handler);
                    return window.ethereum;
                },
                removeListener: (event, handler) => {
                    const handlers = listeners[event];
                    if (!handlers) {
                        return window.ethereum;
                    }
                    const index = handlers.indexOf(handler);
                    if (index > -1) {
                        handlers.splice(index, 1);
                    }
                    return window.ethereum;
                },
                enable: () => window.ethereum.request({ method: 'eth_requestAccounts' }),
            };
            window.ethereum.emit = (event, payload) => {
                if (event === '\(Event.chainChanged.rawValue)') {
                    window.ethereum.chainId = payload;
                    window.ethereum.networkVersion = payload;
                }
                if (event === '\(Event.accountsChanged.rawValue)') {
                    window.ethereum.selectedAddress = payload && payload.length ? payload[0] : null;
                }
                const name = event.replace('ethereum.', '');
                (listeners[name] || []).slice().forEach((handler) => handler(payload));
            };
            window.addEventListener('message', ({ data }) => {
                if (!data || data.type !== '\(DappBridgeMessageType.nativeEvent.rawValue)') {
                    return;
                }
                if (data.event === '\(Event.accountsChanged.rawValue)' || data.event === '\(Event.chainChanged.rawValue)') {
                    window.ethereum.emit(data.event, data.payload);
                }
            });
        }
        """
    }

    struct Null: Encodable {
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }

    static func responseJson(_ value: some Encodable) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        do {
            return try String(data: encoder.encode(value), encoding: .utf8)
        } catch {
            Log.w("earn evm response is not encodable", extraInfo: ["error": "\(error)"])
            return nil
        }
    }

    static func chainIdHex(_ chainId: Int) -> String {
        "0x" + String(chainId, radix: 16)
    }
}
