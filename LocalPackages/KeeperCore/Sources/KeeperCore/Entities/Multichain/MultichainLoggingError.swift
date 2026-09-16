import TKLogging

enum MultichainLoggingError: LoggableError {
    case invalidAssetIdentifier(componentCount: Int)
    case missingMnemonic(operation: String)
    case preferredAddressMissing(chain: MultichainChain, type: MultichainWalletAddressType)

    var logDescription: String {
        switch self {
        case let .invalidAssetIdentifier(componentCount):
            return "type=MultichainLoggingError, case=invalidAssetIdentifier, componentCount=\(componentCount)"
        case let .missingMnemonic(operation):
            return "type=MultichainLoggingError, case=missingMnemonic, operation=\(operation)"
        case let .preferredAddressMissing(chain, type):
            return "type=MultichainLoggingError, case=preferredAddressMissing, chain=\(chain.rawValue), addressType=\(type.rawValue)"
        }
    }
}
