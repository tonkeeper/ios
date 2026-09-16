import KeeperCore
import TKCoordinator
import TKCore
import UIKit

@MainActor
final class TokenManagementCoordinatorImplementation<V: UIViewController>: RouterCoordinator<ContainerViewControllerRouter<V>> {
    private let availableChains: [TokenManagementChain]
    private let service: TokenManagementService
    private let appSettingsStore: AppSettingsStore

    private weak var presentedViewController: TokenManagementHostingViewController?
    private var streamContinuation: AsyncStream<TokenManagementCoordinatorEvent>.Continuation?
    private var didEmitEvent = false
    private var didFinishStream = false

    init(
        router: ContainerViewControllerRouter<V>,
        availableChains: [TokenManagementChain],
        service: TokenManagementService,
        appSettingsStore: AppSettingsStore
    ) {
        self.availableChains = availableChains
        self.service = service
        self.appSettingsStore = appSettingsStore
        super.init(router: router)
    }

    override func start() {
        let module = module()
        module.view.didDismissInteractively = { [weak self] in
            self?.finishStream(with: .close)
        }
        presentedViewController = module.view
        router.rootViewController.topPresentedViewController().present(
            module.view,
            animated: true
        )
    }
}

extension TokenManagementCoordinatorImplementation: TokenManagementCoordinator {
    func startHandlingEvents() -> AsyncStream<TokenManagementCoordinatorEvent> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                return continuation.finish()
            }

            streamContinuation = continuation
            didEmitEvent = false
            didFinishStream = false
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.streamContinuation = nil
                }
            }
            start()
        }
    }
}

private extension TokenManagementCoordinatorImplementation {
    func module() -> MVVMModule<
        TokenManagementHostingViewController,
        TokenManagementModuleOutput,
        TokenManagementModuleInput
    > {
        let viewModel = TokenManagementViewModelImplementation(
            availableChains: availableChains,
            service: service,
            appSettingsStore: appSettingsStore
        )
        let viewController = TokenManagementHostingViewController(viewModel: viewModel)
        viewModel.didRequestClose = { [weak self] in
            self?.dismissPresentedViewController(with: .close)
        }
        viewModel.didSaveChanges = { [weak self] update in
            self?.dismissPresentedViewController(with: .save(update: update))
        }

        return MVVMModule(
            view: viewController,
            output: viewModel,
            input: viewModel
        )
    }

    func dismissPresentedViewController(with event: TokenManagementCoordinatorEvent) {
        guard let presentedViewController else {
            finishStream(with: event)
            return
        }

        emitEvent(event)
        presentedViewController.dismissFromCoordinator(animated: true) { [weak self] in
            self?.finishStream()
        }
    }

    func finishStream(with event: TokenManagementCoordinatorEvent) {
        emitEvent(event)
        finishStream()
    }

    func emitEvent(_ event: TokenManagementCoordinatorEvent) {
        guard !didEmitEvent, !didFinishStream else { return }
        didEmitEvent = true
        streamContinuation?.yield(event)
    }

    func finishStream() {
        guard !didFinishStream else { return }
        didFinishStream = true
        streamContinuation?.finish()
        streamContinuation = nil
    }
}
