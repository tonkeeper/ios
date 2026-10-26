import Foundation
import TKBatteryAPI
import TKLogging

extension BatteryAPI.ApiError: LoggableError {
    var logDescription: String {
        let description = LogDescription(type: BatteryAPI.ApiError.self)
        switch self {
        case let .badUrl(underlying):
            return description.with("case", "badUrl").with("underlying", error: underlying).text
        case let .badStatus(status, message):
            return description.with("case", "badStatus").with("status", status).with("message", message).text
        case let .rejected(status, code, message):
            return description.with("case", "rejected").with("status", status).with("code", code).with("message", message).text
        case let .badResponse(underlying):
            return description.with("case", "badResponse").with("underlying", error: underlying).text
        case let .unknown(underlying):
            return description.with("case", "unknown").with("underlying", error: underlying).text
        }
    }
}

extension BatteryAPI {
    enum ApiError: Error, LocalizedError {
        case badUrl(
            underlying: Error?
        )
        case badStatus(
            status: Int,
            message: String
        )
        /// A rejection in the gasless 2.0 format: `code` is the relayer's machine-readable reason.
        case rejected(
            status: Int,
            code: String,
            message: String
        )
        case badResponse(
            underlying: Error?
        )
        case unknown(
            underlying: Error?
        )

        var errorDescription: String? {
            switch self {
            case .badUrl:
                "Bad host"
            case let .badStatus(_, message), let .rejected(_, _, message):
                message
            case let .badResponse(underlying):
                underlying?.localizedDescription ?? "Bad Response"
            case .unknown:
                "Battery Api Error"
            }
        }

        var isCancellation: Bool {
            switch self {
            case let .badUrl(underlying),
                 let .badResponse(underlying),
                 let .unknown(underlying):
                underlying?.isCancelledError == true
            case .badStatus, .rejected:
                false
            }
        }
    }
}

extension BatteryAPI {
    /// A 401 keeps the generic shape the authorization service recovers the device session from.
    static func gaslessRejection(
        status: Int,
        error: Components.Schemas.GaslessV2ErrorBody
    ) -> ApiError {
        guard status != 401 else {
            return .badStatus(status: status, message: error.message)
        }
        return .rejected(status: status, code: error.code, message: error.message)
    }
}
