import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
final class MultichainReceiveCoordinator<V: UIViewController>: RouterCoordinator<ContainerViewControllerRouter<V>>, ReceiveCoordinator {
    var didClose: (() -> Void)?

    enum Addresses {
        case single(ReceiveAddressPreview)
        case multi([ReceiveAddressPreview])
    }

    private let didCopyAddress: ((String) -> Void)?
    private let addresses: Addresses
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private var flowTask: Task<Void, Never>?

    init(
        router: ContainerViewControllerRouter<V>,
        addresses: Addresses,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        didCopyAddress: ((String) -> Void)?
    ) {
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.addresses = addresses
        self.didCopyAddress = didCopyAddress
        super.init(router: router)
    }

    override func start() {
        flowTask?.cancel()
        flowTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            switch addresses {
            case let .single(address):
                await openMultichainReceive(selectedAddress: address)
                didClose?()
            case let .multi(addresses):
                await openReceive(addresses: addresses)
            }
        }
    }
}

extension MultichainReceiveCoordinator {
    private func module(
        address: ReceiveAddressPreview
    ) -> MVVMModule<ReceiveViewController, ReceiveModuleOutput, ReceiveModuleInput> {
        let viewModel = ReceiveViewModelImplementation(
            address: address,
            qrCodeGenerator: keeperCoreMainAssembly.coreAssembly
                .qrCodeGenerator(persistent: true)
        )
        let viewController = ReceiveViewController(
            viewModel: viewModel
        )
        viewModel.didRequestCopy = { [weak self] address in
            self?.didCopyAddress?(address)
        }
        return MVVMModule(
            view: viewController,
            output: viewModel,
            input: viewModel
        )
    }
}

extension MultichainReceiveCoordinator {
    private func openReceive(
        addresses: [ReceiveAddressPreview]
    ) async {
        let module = PickMultichainAddressModule()
        let coordinator = module.makeCoordinator(
            router: router,
            addresses: addresses.map(\.walletAddress)
        )
        addChild(coordinator)

        let events = coordinator.startHandlingEvents()
        for await event in events {
            switch event {
            case let .select(address):
                let preview = addresses.first { $0.walletAddress == address } ?? ReceiveAddressPreview(address: address)
                await openMultichainReceive(selectedAddress: preview)
            case let .copy(address):
                didCopyAddress?(address.address)
            case .close:
                removeChild(coordinator)
                didClose?()
                return
            }
        }

        removeChild(coordinator)
    }

    private func openMultichainReceive(selectedAddress: ReceiveAddressPreview) async {
        let module = module(
            address: selectedAddress
        )
        await withCheckedContinuation { [weak self] (continuation: CheckedContinuation<Void, Never>) in
            guard let self else {
                return continuation.resume()
            }
            weak var presentedReceiveBottomSheetViewController: TKBottomSheetViewController?
            var hasResumed = false
            let resumeOnce: () -> Void = {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume()
            }
            module.output.didRequestClose = {
                guard let presentedReceiveBottomSheetViewController else {
                    return
                }
                presentedReceiveBottomSheetViewController.dismiss(
                    completion: resumeOnce
                )
            }
            let bottomSheetViewController = TKBottomSheetViewController(
                contentViewController: module.view,
                ignoreBottomSafeArea: true
            )
            presentedReceiveBottomSheetViewController = bottomSheetViewController
            bottomSheetViewController.didClose = { _ in
                resumeOnce()
            }
            bottomSheetViewController.present(
                fromViewController: router.rootViewController.topPresentedViewController()
            )
        }
    }
}
