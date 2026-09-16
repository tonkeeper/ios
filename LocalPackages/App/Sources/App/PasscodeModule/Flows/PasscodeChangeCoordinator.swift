import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

final class PasscodeChangeCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didChangePasscode: (() -> Void)?
    var didCancel: (() -> Void)?

    private let passcodeNavigationController = UINavigationController()
    private var passcodeModuleInput: PasscodeModuleInput?
    private weak var passcodeView: PasscodeViewController?
    private var passcodeInputs = [PasscodeInputModuleInput]()

    private let keeperCoreAssembly: KeeperCore.MainAssembly
    private let bruteForceController: PasscodeBruteForceProtection

    init(
        router: NavigationControllerRouter,
        keeperCoreAssembly: KeeperCore.MainAssembly,
        analyticsProvider: AnalyticsProvider? = nil
    ) {
        self.keeperCoreAssembly = keeperCoreAssembly
        // Share the global passcode brute-force counter so the "enter current passcode" step is protected
        // like every other passcode prompt (TK-1472: lockout closes all passcode-input places).
        self.bruteForceController = PasscodeBruteForceController(
            securityStore: keeperCoreAssembly.storesAssembly.securityStore,
            analyticsProvider: analyticsProvider,
            from: .change
        )
        super.init(router: router)
        passcodeNavigationController.setNavigationBarHidden(true, animated: false)
    }

    override func start() {
        open()
    }
}

private extension PasscodeChangeCoordinator {
    func open() {
        let passcodeModule = PasscodeAssembly.module(
            navigationController: passcodeNavigationController
        )

        passcodeModuleInput = passcodeModule.input
        passcodeView = passcodeModule.view

        passcodeModule.output.didTapBackspace = { [weak self] in
            self?.passcodeInputs.last?.didTapBackspace()
        }

        passcodeModule.output.didTapDigit = { [weak self] digit in
            self?.passcodeInputs.last?.didTapDigit(digit)
        }

        if router.rootViewController.viewControllers.isEmpty {
            passcodeModule.view.setupLeftCloseButton { [weak self] in
                self?.didCancel?()
            }
        } else {
            passcodeModule.view.setupBackButton()
        }

        router.push(
            viewController: passcodeModule.view,
            animated: false
        )
        openInputPasscode()
    }

    func openInputPasscode() {
        let passcodeInput = PasscodeInputAssembly.module(
            title: TKLocales.Passcode.enter,
            lockoutUntil: bruteForceController.activeLockoutEndDate()
        )

        // Capture the assembly and brute-force controller directly (not via `self`) so a wrong attempt
        // still advances the global counter / lockout even if the coordinator is torn down mid-dismiss
        // while the input view is briefly retained by UIKit. Both write to the shared SecurityStore and
        // don't reference the coordinator, so there is no retain cycle. (TK-1472)
        passcodeInput.output.validateInput = { [keeperCoreAssembly, bruteForceController] input in
            let isValid = await keeperCoreAssembly.secureAssembly.mnemonicAccess.validatePasscode(
                input
            )
            if isValid {
                await bruteForceController.registerSuccess()
                return .success
            } else {
                let outcome = await bruteForceController.registerFailure()
                return .failed(attemptsLeft: outcome.attemptsLeft, lockoutUntil: outcome.lockoutEndDate)
            }
        }

        passcodeInput.output.didUpdateKeyboardEnabled = { [weak self] isEnabled in
            self?.passcodeView?.setKeyboardEnabled(isEnabled)
        }

        passcodeInput.output.didFinish = { [weak self] passcode in
            self?.openCreatePasscode(oldPasscode: passcode)
        }

        passcodeInputs.append(passcodeInput.input)

        passcodeNavigationController.pushViewController(
            passcodeInput.viewController,
            animated: true
        )
    }

    func openCreatePasscode(oldPasscode: String) {
        let passcodeInput = PasscodeInputAssembly.module(
            title: TKLocales.Passcode.create
        )

        passcodeInput.output.validateInput = { _ in
            .none
        }

        passcodeInput.output.didFinish = { [weak self] passcode in
            self?.openReenterPasscode(oldPasscode: oldPasscode, newPasscode: passcode)
        }

        passcodeInputs.append(passcodeInput.input)

        passcodeNavigationController.pushViewController(
            passcodeInput.viewController,
            animated: true
        )
    }

    func openReenterPasscode(oldPasscode: String, newPasscode: String) {
        let passcodeInput = PasscodeInputAssembly.module(
            title: TKLocales.Passcode.reenter
        )

        passcodeInput.output.validateInput = { passcode in
            passcode == newPasscode ? .success : .failed
        }

        passcodeInput.output.didFinish = { [weak self] _ in
            guard let self else { return }
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await keeperCoreAssembly.mnemonicAccess.changePasscode(
                        old: oldPasscode,
                        new: newPasscode
                    )
                    do {
                        try keeperCoreAssembly.mnemonicAccess.deletePasscode()
                    } catch {
                        Log.e("🪵 failed to remove old passcode from vault due to error: \(error)")
                    }
                    await self.keeperCoreAssembly.storesAssembly.securityStore.setIsBiometryEnable(false)
                    await MainActor.run {
                        self.didChangePasscode?()
                    }
                } catch {
                    await MainActor.run {
                        ToastPresenter.showToast(configuration: .failed)
                    }
                }
            }
        }

        passcodeInput.output.didFailed = { [weak self] in
            self?.passcodeNavigationController.popViewController(animated: true)
            _ = self?.passcodeInputs.popLast()
        }

        passcodeInputs.append(passcodeInput.input)

        passcodeNavigationController.pushViewController(
            passcodeInput.viewController,
            animated: true
        )
    }
}
