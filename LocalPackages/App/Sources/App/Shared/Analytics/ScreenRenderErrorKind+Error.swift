import Foundation
import KeeperCore
import TKUIKit

extension ScreenRenderErrorKind {
    init(_ error: Error) {
        switch error {
        case let error as URLError:
            self.init(error)
        case is DecodingError:
            self = .decode
        case let error as MultichainServiceError:
            switch error {
            case .connectionError: self = .network
            case .apiError: self = .server
            case .cancelled: self = .unknown
            }
        case let error as LoadShelvesFailure:
            switch error {
            case .networkError: self = .network
            case .apiError: self = .server
            }
        case let error as TonkeeperAPIError:
            switch error {
            case .badStatus: self = .server
            case .badResponse: self = .decode
            case let .transportError(underlying):
                self = (underlying as? URLError).map(ScreenRenderErrorKind.init) ?? .network
            case .cancelled, .incorrectUrl: self = .unknown
            }
        default:
            self = .unknown
        }
    }

    private init(_ error: URLError) {
        switch error.code {
        case .timedOut:
            self = .timeout
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            self = .offline
        default:
            self = .network
        }
    }
}
