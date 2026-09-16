import Foundation
import TonAPI

public enum WalletMigrationError: Error, Equatable {
    case insufficientTonForGas(required: UInt64, available: UInt64)
    case insufficientTrxForFees(required: UInt64, available: UInt64)
    case inactiveTronAccount

    public init?(apiError: Error) {
        guard let errorResponse = apiError as? ErrorResponse,
              case let .error(_, data, _, _) = errorResponse,
              let data
        else {
            return nil
        }

        if let defaultError = try? JSONDecoder().decode(GetOpenapiJsonDefaultResponse.self, from: data),
           let details = defaultError.details
        {
            self = .insufficientTonForGas(
                required: UInt64(details._required),
                available: UInt64(details.available)
            )
            return
        }

        if let modelError = try? JSONDecoder().decode(ModelError.self, from: data),
           let parsed = Self(errorMessage: modelError.error)
        {
            self = parsed
            return
        }

        return nil
    }

    init?(errorMessage: String) {
        guard errorMessage.hasPrefix("INSUFFICIENT_TON_FOR_GAS") else {
            return nil
        }

        let requiredPattern = #"required\s+(\d+)\s+nanotons?"#
        let availablePattern = #"available\s+(\d+)"#

        guard let required = Self.firstMatch(in: errorMessage, pattern: requiredPattern),
              let available = Self.firstMatch(in: errorMessage, pattern: availablePattern)
        else {
            return nil
        }

        self = .insufficientTonForGas(required: required, available: available)
    }

    public static func sendFailureMessage(from error: Error) -> String {
        if case let ErrorResponse.error(_, data, _, _) = error,
           let data,
           let modelError = try? JSONDecoder().decode(ModelError.self, from: data),
           !modelError.error.isEmpty
        {
            return modelError.error
        }
        return error.localizedDescription
    }

    private static func firstMatch(in string: String, pattern: String) -> UInt64? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: string,
                  range: NSRange(string.startIndex..., in: string)
              ),
              let range = Range(match.range(at: 1), in: string),
              let value = UInt64(string[range])
        else {
            return nil
        }
        return value
    }
}
