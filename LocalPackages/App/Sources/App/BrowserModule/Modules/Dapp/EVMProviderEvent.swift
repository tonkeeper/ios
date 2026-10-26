import Foundation

enum EVMProviderEvent: Equatable {
    case accountsChanged([String])
    case chainChanged(chainIdHex: String)

    var json: String? {
        switch self {
        case let .accountsChanged(accounts):
            DappNativeBridge.eventJson(name: EVMProviderBridge.Event.accountsChanged.rawValue, payload: accounts)
        case let .chainChanged(chainIdHex):
            DappNativeBridge.eventJson(name: EVMProviderBridge.Event.chainChanged.rawValue, payload: chainIdHex)
        }
    }
}
