import Foundation
import ReownWalletKit
import TKLogging

struct WalletConnectDefaultSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        Log.walletConnect.i("websocket create", extraInfo: [
            "url": url.redactedLogValue,
        ])
        return WalletConnectURLSessionWebSocket(url: url)
    }
}

final class WalletConnectURLSessionWebSocket: NSObject, WebSocketConnecting, URLSessionWebSocketDelegate {
    private(set) var isConnected: Bool = false
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var onText: ((String) -> Void)?
    var request: URLRequest

    private var task: URLSessionWebSocketTask?
    private lazy var session = URLSession(
        configuration: .default,
        delegate: self,
        delegateQueue: nil
    )

    init(url: URL) {
        self.request = URLRequest(url: url)
        super.init()
    }

    func connect() {
        guard task == nil else {
            Log.walletConnect.i("websocket connect skipped: task already exists", extraInfo: [
                "url": request.url?.redactedLogValue ?? "unknown",
                "isConnected": "\(isConnected)",
            ])
            return
        }
        Log.walletConnect.i("websocket connect started", extraInfo: [
            "url": request.url?.redactedLogValue ?? "unknown",
        ])
        let task = session.webSocketTask(with: request)
        self.task = task
        task.resume()
        receiveNextMessage()
    }

    func disconnect() {
        Log.walletConnect.i("websocket disconnect requested", extraInfo: [
            "url": request.url?.redactedLogValue ?? "unknown",
            "isConnected": "\(isConnected)",
            "hasTask": "\(task != nil)",
        ])
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        if isConnected {
            isConnected = false
            onDisconnect?(nil)
            Log.walletConnect.i("websocket disconnected locally", extraInfo: [
                "url": request.url?.redactedLogValue ?? "unknown",
            ])
        }
    }

    func write(string: String, completion: (() -> Void)?) {
        guard let task else {
            let error = WalletConnectWebSocketConnectionError.noActiveTask
            isConnected = false
            Log.walletConnect.i("websocket send skipped: no active task", error: error, extraInfo: [
                "url": request.url?.redactedLogValue ?? "unknown",
                "bytes": "\(string.utf8.count)",
            ])
            onDisconnect?(error)
            completion?()
            return
        }

        Log.walletConnect.i("websocket send started", extraInfo: [
            "url": request.url?.redactedLogValue ?? "unknown",
            "bytes": "\(string.utf8.count)",
        ])
        task.send(.string(string)) { error in
            if let error {
                Log.walletConnect.i("websocket send failed", error: error, extraInfo: [
                    "url": self.request.url?.redactedLogValue ?? "unknown",
                    "bytes": "\(string.utf8.count)",
                ])
            } else {
                Log.walletConnect.i("websocket send finished", extraInfo: [
                    "url": self.request.url?.redactedLogValue ?? "unknown",
                    "bytes": "\(string.utf8.count)",
                ])
            }
            completion?()
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        isConnected = true
        Log.walletConnect.i("websocket connected", extraInfo: [
            "url": request.url?.redactedLogValue ?? "unknown",
            "protocol": `protocol` ?? "nil",
        ])
        onConnect?()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        isConnected = false
        task = nil
        Log.walletConnect.i("websocket closed by remote", extraInfo: [
            "url": request.url?.redactedLogValue ?? "unknown",
            "closeCode": "\(closeCode.rawValue)",
            "reasonBytes": "\(reason?.count ?? 0)",
        ])
        onDisconnect?(nil)
    }

    private func receiveNextMessage() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(message):
                switch message {
                case let .string(text):
                    Log.walletConnect.i("websocket text received", extraInfo: [
                        "url": self.request.url?.redactedLogValue ?? "unknown",
                        "bytes": "\(text.utf8.count)",
                    ])
                    self.onText?(text)
                case let .data(data):
                    Log.walletConnect.i("websocket data received", extraInfo: [
                        "url": self.request.url?.redactedLogValue ?? "unknown",
                        "bytes": "\(data.count)",
                    ])
                    if let text = String(data: data, encoding: .utf8) {
                        self.onText?(text)
                    } else {
                        Log.walletConnect.i("websocket data skipped: not utf8", extraInfo: [
                            "url": self.request.url?.redactedLogValue ?? "unknown",
                            "bytes": "\(data.count)",
                        ])
                    }
                @unknown default:
                    Log.walletConnect.i("websocket unknown message received", extraInfo: [
                        "url": self.request.url?.redactedLogValue ?? "unknown",
                    ])
                }
                self.receiveNextMessage()
            case let .failure(error):
                self.isConnected = false
                self.task = nil
                Log.walletConnect.i("websocket receive failed", error: error, extraInfo: [
                    "url": self.request.url?.redactedLogValue ?? "unknown",
                ])
                self.onDisconnect?(error)
            }
        }
    }
}

private enum WalletConnectWebSocketConnectionError: LocalizedError, LoggableError {
    case noActiveTask

    var errorDescription: String? {
        switch self {
        case .noActiveTask:
            return "WalletConnect websocket has no active task"
        }
    }

    var logDescription: String {
        "type=WalletConnectWebSocketConnectionError, case=noActiveTask"
    }
}

private extension URL {
    var redactedLogValue: String {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return "invalidURL"
        }
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        return components.string ?? "invalidURL"
    }
}
