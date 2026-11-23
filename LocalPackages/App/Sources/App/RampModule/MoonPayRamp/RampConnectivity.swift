import Foundation
import MoonPay

enum RampConnectivity {
    /// A request that failed because the device has no network, as URLSession reports it, also
    /// inside MoonPay's transport error.
    static func isOfflineError(_ error: Error) -> Bool {
        switch error {
        case let error as URLError:
            offlineCodes.contains(error.code)
        case let MoonPayAPIError.transport(underlying):
            isOfflineError(underlying)
        default:
            false
        }
    }

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
    ]
}
