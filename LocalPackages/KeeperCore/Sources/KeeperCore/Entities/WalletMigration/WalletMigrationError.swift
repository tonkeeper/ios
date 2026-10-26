import Foundation

@frozen public enum WalletMigrationError: Error, Equatable {
    case insufficientTonForGas(required: UInt64, available: UInt64)
    case insufficientTrxForFees(required: UInt64, available: UInt64)
    case inactiveTronAccount

    public init?(apiError: Error) {
        guard let data = apiError.tonAPIError?.body,
              let errorBody = try? JSONDecoder().decode(ErrorBody.self, from: data)
        else {
            return nil
        }

        if let details = errorBody.details {
            self = .insufficientTonForGas(
                required: UInt64(details.required),
                available: UInt64(details.available)
            )
            return
        }

        if let parsed = Self(errorMessage: errorBody.error) {
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
        if let data = error.tonAPIError?.body,
           let errorBody = try? JSONDecoder().decode(ErrorBody.self, from: data),
           !errorBody.error.isEmpty
        {
            return errorBody.error
        }
        return error.localizedDescription
    }

    private struct ErrorBody: Decodable {
        struct Details: Decodable {
            let required: Int64
            let available: Int64
        }

        let error: String
        let details: Details?
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
