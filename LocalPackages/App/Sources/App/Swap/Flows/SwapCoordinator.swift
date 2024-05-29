import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKCore

final class SwapCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let swapSearchTokenController: SwapSearchTokenController
    private let swapInfoController: SwapInfoController
    
    var didFinish: (() -> Void)?
    
    init(
        router: NavigationControllerRouter,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        swapSearchTokenController: SwapSearchTokenController,
        swapInfoController: SwapInfoController
    ) {
        self.swapSearchTokenController = swapSearchTokenController
        self.swapInfoController = swapInfoController
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        super.init(router: router)
    }
    
    public override func start() {
        router.rootViewController.configureDefaultAppearance()
        openSwapInfo()
    }
}

private extension SwapCoordinator {
    func openSwapInfo() {
        let module = SwapInfoAssembly.module(
            swapInfoController: swapInfoController
        )
        
        module.view.navigationItem.setupButton(with: .TKUIKit.Icons.Size16.sliders) { [weak self, module] in
            let currentTolerance = module.output.currentTolerance
            self?.openSettings(currentTolerance: currentTolerance) { tolerance in
                module.input.setTolerance(toleance: tolerance)
            }
        }
        
        module.view.setupRightCloseButton { [weak self] in
            self?.didFinish?()
        }
        
        module.output.didTapTokenPicker = { [weak self] wallet, token, type in
            guard let self else { return }
            self.openTokenPicker(wallet: wallet, token: token, sourceViewController: router.rootViewController, completion: { token in
                switch type {
                case .send:
                    module.input.setSendToken(token: token)
                case .receive:
                    module.input.setReceiveToken(token: token)
                }
                
            })
        }
        
        module.output.didTapSearchTokenPicker = { [weak self] type in
            guard let self else { return }
            self.openSearchTokens { jetton in
                let token = Token.jetton(.init(jettonInfo: jetton))
                switch type {
                case .send:
                    module.input.setSendToken(token: token)
                case .receive:
                    module.input.setReceiveToken(token: token)
                }
            }
        }
        
        module.output.didTapContinue = { [weak self] swapModel in
            self?.openSwapConfirmation(
                swapModel: swapModel
            )
        }
        
        router.push(viewController: module.view, animated: false)
    }
    
    func openSwapConfirmation(swapModel: SwapModel) {
        guard let recipient = swapModel.recipient else { return }
        let sendConfirmationController = keeperCoreMainAssembly.sendConfirmationController(
            wallet: swapModel.wallet,
            recipient: recipient,
            sendItem: swapModel.sendItem,
            comment: nil
          )
        
        let module = SwapConfirmationAssembly.module(
            swapInfoController: swapInfoController,
            sendConfirmationController: sendConfirmationController
        )
        
        module.view.didTapClose = { [weak self] in
            self?.didFinish?()
        }
        
        module.view.didTapCancel = { [weak self] in
            self?.router.pop(animated: true)
        }
        
        module.output.didFinish = { [weak self] in
            self?.didFinish?()
        }
        
        module.output.didRequireConfirmation = { [weak self] in
          guard let self else { return false }
          return await self.openConfirmation(fromViewController: self.router.rootViewController)
        }
        
        router.push(viewController: module.view, animated: true)
    }
    
    func openTokenPicker(wallet: Wallet, token: Token, sourceViewController: UIViewController, completion: @escaping (Token) -> Void) {
        let module = TokenPickerAssembly.module(
            tokenPickerController: keeperCoreMainAssembly.tokenPickerController(
                wallet: wallet,
                selectedToken: token
            )
        )
        
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
        
        module.output.didSelectToken = { token in
            completion(token)
        }
        
        module.output.didFinish = {  [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }
        
        bottomSheetViewController.present(fromViewController: sourceViewController)
    }
    
    func openSearchTokens(completion: @escaping (JettonInfo) -> Void) {
        let module = SwapSearchTokenAssembly.module(
            swapSearchTokenController: swapSearchTokenController
        )
        
        module.output.didSelectToken = { token in
            completion(token)
        }
        
        module.output.didFinish = { [weak router] in
            router?.dismiss()
        }
        
        router.present(module.view, animated: true)
    }
    
    func openSettings(currentTolerance: Int, didSelectTolerance: ((Int) -> Void)?) {
        let module = SwapSettingsAssembly.module(currentTolerance: currentTolerance)
        
        module.output.didSelectTolerance = { [weak self] in
            didSelectTolerance?($0)
            self?.router.dismiss(animated: true)
        }
        
        module.view.didTapClose = { [weak self] in
            self?.router.dismiss(animated: true)
        }
        
        router.present(module.view, animated: true)
    }
    
    func openConfirmation(fromViewController: UIViewController) async -> Bool {
      return await Task<Bool, Never> { @MainActor in
        return await withCheckedContinuation { [weak self, keeperCoreMainAssembly] (continuation: CheckedContinuation<Bool, Never>) in
          guard let self = self else { return }
          let coordinator = PasscodeModule(
            dependencies: PasscodeModule.Dependencies(
              passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
            )
          ).passcodeConfirmationCoordinator()
          
          coordinator.didCancel = { [weak self, weak coordinator] in
            continuation.resume(returning: false)
            coordinator?.router.dismiss(completion: {
              guard let coordinator else { return }
              self?.removeChild(coordinator)
            })
          }
          
          coordinator.didConfirm = { [weak self, weak coordinator] in
            continuation.resume(returning: true)
            coordinator?.router.dismiss(completion: {
              guard let coordinator else { return }
              self?.removeChild(coordinator)
            })
          }
          
          self.addChild(coordinator)
          coordinator.start()
          
          fromViewController.present(coordinator.router.rootViewController, animated: true)
        }
      }.value
    }
}
