import TKLogging

extension MultichainServiceError: LoggableError {
    public var logDescription: String {
        let description = LogDescription(type: MultichainServiceError.self)
        switch self {
        case .cancelled:
            return description.with("case", "cancelled").text
        case .connectionError:
            return description.with("case", "connectionError").text
        case let .apiError(message):
            return description.with("case", "apiError").with("message", message).text
        }
    }
}

extension MultichainClientAPIError: LoggableError {
    public var logDescription: String {
        let description = LogDescription(type: MultichainClientAPIError.self)
        switch self {
        case .cancelled:
            return description.with("case", "cancelled").text
        case let .connectionError(underlying):
            return description.with("case", "connectionError").with("underlying", error: underlying).text
        case let .badResponse(underlying):
            return description.with("case", "badResponse").with("underlying", error: underlying).text
        case let .badStatus(message):
            return description.with("case", "badStatus").with("message", message).text
        case let .unauthorized(message):
            return description.with("case", "unauthorized").with("reason", message).text
        case let .forbidden(message):
            return description.with("case", "forbidden").with("message", message).text
        case let .undocumented(statusCode):
            return description.with("case", "undocumented").with("statusCode", statusCode).text
        }
    }
}

extension MultichainSwapAPIError: LoggableError {
    public var logDescription: String {
        let description = LogDescription(type: MultichainSwapAPIError.self)
        switch self {
        case let .badRequest(message, code, requestId):
            return description
                .with("case", "badRequest")
                .with("message", message)
                .with("code", code)
                .with("requestId", requestId)
                .text
        case let .notFound(message, code, requestId):
            return description
                .with("case", "notFound")
                .with("message", message)
                .with("code", code)
                .with("requestId", requestId)
                .text
        case let .internalServerError(message, code, requestId):
            return description
                .with("case", "internalServerError")
                .with("message", message)
                .with("code", code)
                .with("requestId", requestId)
                .text
        case let .badResponse(diagnostic):
            return description.with("case", "badResponse").with("underlying", diagnostic.message).text
        case let .transportError(diagnostic):
            return description.with("case", "transportError").with("underlying", diagnostic.message).text
        case let .unknown(statusCode):
            return description.with("case", "unknown").with("statusCode", statusCode).text
        }
    }
}

extension MultichainRampAPIError: LoggableError {
    public var logDescription: String {
        let description = LogDescription(type: MultichainRampAPIError.self)
        switch self {
        case .cancelled:
            return description.with("case", "cancelled").text
        case let .badRequest(message, code, requestId):
            return description
                .with("case", "badRequest")
                .with("message", message)
                .with("code", code)
                .with("requestId", requestId)
                .text
        case let .notFound(message, requestId):
            return description
                .with("case", "notFound")
                .with("message", message)
                .with("requestId", requestId)
                .text
        case let .internalServerError(message, requestId):
            return description
                .with("case", "internalServerError")
                .with("message", message)
                .with("requestId", requestId)
                .text
        case let .badResponse(diagnostic):
            return description.with("case", "badResponse").with("underlying", diagnostic.message).text
        case let .transportError(diagnostic):
            return description.with("case", "transportError").with("underlying", diagnostic.message).text
        case let .unknown(statusCode):
            return description.with("case", "unknown").with("statusCode", statusCode).text
        }
    }
}
