import Foundation

@WalletConnectActor
final class WalletConnectStartupCoordinator: Sendable {
    private let eventStream: WalletConnectEventStream
    private let network: WalletConnectWalletKitClientProtocol

    private var startTask: Task<Void, Error>?
    private var started = false

    init(
        eventStream: WalletConnectEventStream,
        network: WalletConnectWalletKitClientProtocol
    ) {
        self.eventStream = eventStream
        self.network = network
    }

    deinit {
        startTask?.cancel()
    }

    func start() async throws(WalletConnectConfigurationError) -> Bool {
        if started {
            return false
        }

        let task: Task<Void, Error>
        if let startTask {
            task = startTask
        } else {
            task = Task { @WalletConnectActor [network, eventStream] in
                try network.configureIfNeeded()
                eventStream.subscribe()
            }
            startTask = task
        }

        do {
            try await task.value
            let shouldHydratePendingProposals = !started
            started = true
            startTask = nil
            return shouldHydratePendingProposals
        } catch let error as WalletConnectConfigurationError {
            startTask = nil
            throw error
        } catch {
            startTask = nil
            throw .sdk(message: error.logDescription)
        }
    }
}
