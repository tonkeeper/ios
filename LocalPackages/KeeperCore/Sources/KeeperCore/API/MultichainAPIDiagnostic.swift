import TKLogging

public struct MultichainAPIDiagnostic: Sendable, Hashable {
    public let typeName: String
    public let message: String

    init(error: Error) {
        typeName = String(reflecting: type(of: error))
        message = error.logDescription
    }
}
