import KeeperCore
import TKCoordinator

enum TokenManagementCoordinatorEvent {
    case save(update: TokenManagementVisibilityUpdate)
    case close
}

@MainActor
protocol TokenManagementCoordinator: Coordinator {
    func startHandlingEvents() -> AsyncStream<TokenManagementCoordinatorEvent>
}
