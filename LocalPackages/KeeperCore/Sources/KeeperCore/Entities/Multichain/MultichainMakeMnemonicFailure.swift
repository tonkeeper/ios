import TKLogging

public enum MultichainMakeMnemonicFailure: LoggableError {
    case unknown(message: String)

    public var logDescription: String {
        "type=MultichainMakeMnemonicFailure, case=unknown"
    }
}
