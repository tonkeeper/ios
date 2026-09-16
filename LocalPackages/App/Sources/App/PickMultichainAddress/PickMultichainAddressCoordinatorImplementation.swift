import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
final class PickMultichainAddressCoordinatorImplementation<V: UIViewController>: RouterCoordinator<ContainerViewControllerRouter<V>> {
    private let addresses: [MultichainWalletAddress]

    private weak var presentedViewController: PickMultichainAddressViewController?
    private var streamContinuation: AsyncStream<PickMultichainAddressCoordinatorEvent>.Continuation?
    private var didFinishStream = false

    init(
        router: ContainerViewControllerRouter<V>,
        addresses: [MultichainWalletAddress]
    ) {
        self.addresses = addresses
        super.init(router: router)
    }

    override func start() {
        let module = module()
        module.view.didDismissInteractively = { [weak self] in
            self?.finishStream()
        }
        presentedViewController = module.view
        router.rootViewController.topPresentedViewController().present(
            module.view,
            animated: true
        )
    }
}

extension PickMultichainAddressCoordinatorImplementation: PickMultichainAddressCoordinator {
    func startHandlingEvents() -> AsyncStream<PickMultichainAddressCoordinatorEvent> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                return continuation.finish()
            }
            streamContinuation = continuation
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

private extension PickMultichainAddressCoordinatorImplementation {
    func module() -> MVVMModule<
        PickMultichainAddressViewController,
        PickMultichainAddressModuleOutput,
        PickMultichainAddressModuleInput
    > {
        let viewModel = PickMultichainAddressViewModelImplementation(addresses: addresses)
        viewModel.didSelectAddress = { [weak self] address in
            self?.streamContinuation?.yield(.select(address))
        }
        viewModel.didCopyAddress = { [weak self] address in
            self?.streamContinuation?.yield(.copy(address))
        }
        viewModel.didRequestClose = { [weak self] in
            self?.dismissPresentedViewController {
                self?.finishStream()
            }
        }
        let viewController = PickMultichainAddressViewController(viewModel: viewModel)
        return MVVMModule(
            view: viewController,
            output: viewModel,
            input: viewModel
        )
    }

    func dismissPresentedViewController(completion: (() -> Void)? = nil) {
        guard let presentedViewController else {
            completion?()
            return
        }

        presentedViewController.dismissFromCoordinator(
            animated: true,
            completion: completion
        )
    }

    func finishStream() {
        guard !didFinishStream else { return }
        didFinishStream = true
        streamContinuation?.yield(.close)
        streamContinuation?.finish()
        streamContinuation = nil
    }
}
