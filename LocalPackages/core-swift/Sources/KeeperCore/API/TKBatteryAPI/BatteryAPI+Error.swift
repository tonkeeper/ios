import Foundation

public extension BatteryAPI {
    enum ApiError: Error, LocalizedError {
        case badUrl(
            underlying: Error?
        )
        case badStatus(
            status: Int,
            message: String
        )
        case badResponse(
            underlying: Error?
        )
        case unknown(
            underlying: Error?
        )

        public var errorDescription: String? {
            switch self {
            case .badUrl:
                "Bad host"
            case let .badStatus(_, message):
                message
            case let .badResponse(underlying):
                underlying?.localizedDescription ?? "Bad Response"
            case .unknown:
                "Battery Api Error"
            }
        }
    }
}
