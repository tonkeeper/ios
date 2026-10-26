import Foundation
import KeeperCore

struct EarnSigningEvent: Equatable {
    enum Stage: Equatable {
        case requested
        case signed
        case rejected
        case failed(EarnSigningFailure)
    }

    let method: WalletConnectMethod
    let chain: WalletConnectChain
    let pageURL: URL?
    let stage: Stage
}

enum EarnSigningFailure: Equatable {
    case noAccount
    case invalidRequest(WalletConnectRequestParsingError)
    case signer(WalletConnectSigningError)
    case unexpectedResponse
}
