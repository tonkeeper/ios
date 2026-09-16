import Foundation

public final class WalletConnectSessionsStore: Store<WalletConnectSessionsStore.Event, [WalletConnectSession]> {
    public enum Event {
        case didUpdateSessions
        case didFailDisconnect(message: String)
    }

    private let walletConnectService: any WalletConnectService
    private var serviceEventsTask: Task<Void, Never>?

    init(walletConnectService: any WalletConnectService) {
        self.walletConnectService = walletConnectService
        super.init(state: [])
        bindServiceEvents()
    }

    deinit {
        serviceEventsTask?.cancel()
    }

    override public func createInitialState() -> [WalletConnectSession] {
        []
    }

    public func refresh() {
        Task { [weak self, walletConnectService] in
            let sessions = await walletConnectService.activeSessions()
            self?.setSessions(sessions)
        }
    }

    public func disconnect(topics: [String]) {
        guard !topics.isEmpty else {
            return
        }
        Task { [weak self, walletConnectService] in
            guard let self else { return }

            var failedMessages = [String]()
            for topic in topics {
                do {
                    try await walletConnectService.disconnect(topic: topic)
                } catch {
                    failedMessages.append(disconnectErrorMessage(error))
                }
            }

            let sessions = await walletConnectService.activeSessions()
            setSessions(sessions)

            if let message = failedMessages.first {
                sendEvent(.didFailDisconnect(message: message))
            }
        }
    }

    private func bindServiceEvents() {
        serviceEventsTask = Task { [weak self, walletConnectService] in
            let stream = await walletConnectService.events()
            for await event in stream {
                guard let self else { return }
                switch event {
                case .sessionSettled,
                     .sessionDeleted:
                    refresh()
                default:
                    break
                }
            }
        }
    }

    private func setSessions(_ sessions: [WalletConnectSession]) {
        updateState { _ in
            StateUpdate(newState: sessions)
        } completion: { [weak self] _ in
            self?.sendEvent(.didUpdateSessions)
        }
    }

    private func disconnectErrorMessage(_ error: Error) -> String {
        switch error {
        case let error as WalletConnectResponseError:
            return error.errorDescription ?? "\(error)"
        default:
            return (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}
