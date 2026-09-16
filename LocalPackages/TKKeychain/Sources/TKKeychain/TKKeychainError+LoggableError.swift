import TKLogging

extension TKKeychainError: LoggableError {
    public var logDescription: String {
        switch self {
        case .corruptedData:
            return "type=TKKeychainError, case=corruptedData"
        case .noItem:
            return "type=TKKeychainError, case=noItem"
        case let .other(status):
            return "type=TKKeychainError, case=other, osStatus=\(status)"
        }
    }
}

extension TKKeychainVaultError: LoggableError {
    public var logDescription: String {
        switch self {
        case .unexpectedData:
            return "type=TKKeychainVaultError, case=unexpectedData"
        case .decodingError:
            return "type=TKKeychainVaultError, case=decodingError"
        case .encodingError:
            return "type=TKKeychainVaultError, case=encodingError"
        }
    }
}
