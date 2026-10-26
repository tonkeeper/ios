import TKScreenKit

extension TKBridgeWebViewController.LoadFailure {
    var errorCode: String {
        switch self {
        case let .network(domain, code):
            "\(domain):\(code)"
        case .httpError:
            "http_error"
        case .processTerminated:
            "web_content_process_terminated"
        }
    }

    var httpStatus: Int? {
        guard case let .httpError(status) = self else { return nil }
        return status
    }
}
