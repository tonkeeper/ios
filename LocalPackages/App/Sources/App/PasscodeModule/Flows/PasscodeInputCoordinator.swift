import KeeperCore
import KeeperCoreSensitive
import LocalAuthentication
import Security
import TKCoordinator
import TKCore
import TKKeychain
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

protocol PasscodeInputValidator {
    func validate(passcode: String) async -> PasscodeInputValidationResult
    func getPasscode() throws -> String
    func refreshStoredPasscode(_ passcode: String) throws
    /// Non-interactive probe of the biometry-protected item, used to tell an
    /// invalidated enrolled set apart from a plain failed match.
    func biometryAccessProbe() -> BiometryAccessProbe
    /// Whether the biometry-protected item already uses `biometryCurrentSet`.
    /// When `false`, a legacy `biometryAny` item needs a one-time migration.
    func isBiometryItemMigrated() -> Bool
}

extension PasscodeInputValidator {
    func biometryAccessProbe() -> BiometryAccessProbe {
        .indeterminate
    }

    /// Default: storage with no `biometryCurrentSet` item has nothing to migrate.
    func isBiometryItemMigrated() -> Bool {
        true
    }
}

protocol PasscodeInputBiometryProvider {
    func getBiometryState() async -> TKKeyboardView.Biometry
}

final class PasscodeInputCoordinator: RouterCoordinator<NavigationControllerRouter> {
    enum Context {
        case entry
        case confirmation
    }

    var didInputPasscode: ((String) -> Void)?
    var didCancel: (() -> Void)?
    var didLogout: (() -> Void)?

    private let validator: PasscodeInputValidator
    private let biometryProvider: PasscodeInputBiometryProvider
    private let securityStore: SecurityStore
    private let bruteForceController: PasscodeBruteForceProtection
    private let context: Context
    private var didShowBiometryChangedWarning = false

    init(
        router: NavigationControllerRouter,
        context: Context,
        validator: PasscodeInputValidator,
        biometryProvider: PasscodeInputBiometryProvider,
        securityStore: SecurityStore,
        bruteForceController: PasscodeBruteForceProtection
    ) {
        self.context = context
        self.validator = validator
        self.biometryProvider = biometryProvider
        self.securityStore = securityStore
        self.bruteForceController = bruteForceController
        super.init(router: router)
        router.rootViewController.modalPresentationStyle = .fullScreen
        router.rootViewController.modalTransitionStyle = .crossDissolve
    }

    override func start() {
        openPasscode()
    }
}

private extension PasscodeInputCoordinator {
    func openPasscode() {
        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let passcodeInputModule = PasscodeInputAssembly.module(
            title: TKLocales.Passcode.enter,
            lockoutUntil: bruteForceController.activeLockoutEndDate()
        )

        let passcodeModule = PasscodeAssembly.module(
            navigationController: navigationController
        )

        // Capture the validator and brute-force controller directly (not via `self`) so a wrong
        // attempt still advances the global counter / lockout even if the coordinator is torn down
        // mid-dismiss while the input view is briefly retained by UIKit. Both write to the shared
        // SecurityStore and don't reference the coordinator, so there is no retain cycle. (TK-1472)
        passcodeInputModule.output.validateInput = { [validator, bruteForceController] input in
            let result = await validator.validate(passcode: input)
            switch result {
            case .success:
                await bruteForceController.registerSuccess()
                return .success
            case .failed:
                let outcome = await bruteForceController.registerFailure()
                return .failed(attemptsLeft: outcome.attemptsLeft, lockoutUntil: outcome.lockoutEndDate)
            case .none:
                return .none
            }
        }

        passcodeInputModule.output.didUpdateKeyboardEnabled = { [weak passcodeView = passcodeModule.view] isEnabled in
            passcodeView?.setKeyboardEnabled(isEnabled)
        }

        passcodeInputModule.output.didEndLockout = { [weak passcodeInput = passcodeModule.input] in
            // Lockout ended: just re-activate the biometry button (no auto-prompt). The store's
            // lockoutEndDate is now in the past, so `biometryProvider` no longer suppresses it. (TK-1472)
            passcodeInput?.evaluateBiometry(autoPrompt: false)
        }

        passcodeInputModule.output.didFinish = { [weak self] passcode in
            self?.refreshBiometryProtectedPasscode(passcode)
            self?.didInputPasscode?(passcode)
        }
        passcodeModule.output.didTapBackspace = {
            passcodeInputModule.input.didTapBackspace()
        }

        passcodeModule.output.didTapDigit = { digit in
            passcodeInputModule.input.didTapDigit(digit)
        }

        passcodeModule.output.didTapBiometry = { [weak self, validator] in
            Task.detached(priority: .userInitiated) {
                do {
                    let passcode = try validator.getPasscode()
                    await MainActor.run {
                        passcodeInputModule.input.didSetInput(passcode)
                    }
                } catch {
                    Log.w("Failed to fetch passcode from repository", extraInfo: [
                        "error": error.localizedDescription,
                    ])
                    await MainActor.run {
                        guard let self else { return }
                        if case .invalidated = self.classifyBiometryFailure(error) {
                            self.showBiometryChangedWarningIfNeeded()
                        }
                    }
                }
            }
        }

        passcodeModule.output.biometryProvider = { [weak self] in
            guard let self else { return .none }

            // Suppress biometry while locked out: matches the dimmed keypad in the design and prevents an
            // auto-prompt at presentation from bypassing an active lockout (TK-1472).
            guard self.bruteForceController.activeLockoutEndDate() == nil else { return .none }

            let state = await self.biometryProvider.getBiometryState()
            switch state {
            case .faceId, .touchId:
                // Biometry is enrolled and enabled, but the stored biometry cache
                // was invalidated by an enrollment change: hide the now-dead
                // biometry button and surface the recovery alert instead of
                // offering a tap that can only fail. The passcode entry re-saves
                // the cache.
                if self.isBiometryCacheInvalidated() {
                    await MainActor.run {
                        self.showBiometryChangedWarningIfNeeded()
                    }
                    return .none
                }
                return state
            case .none:
                // When biometry is unavailable the keyboard skips the auto-unlock,
                // so an enrollment removal would otherwise go undetected. Probe for
                // it explicitly so the recovery alert still shows.
                await MainActor.run {
                    self.showBiometryChangedAlertIfUnavailableInvalidated()
                }
                return .none
            }
        }

        switch context {
        case .entry:
            passcodeModule.view.setupLogoutButton(title: TKLocales.Passcode.logout) { [weak self] in
                self?.showLogoutConfirmationAlert { self?.didLogout?() }
            }
        case .confirmation:
            passcodeModule.view.setupLeftCloseButton { [weak self] in
                self?.didCancel?()
            }
        }

        navigationController.pushViewController(passcodeInputModule.viewController, animated: false)

        router.push(viewController: passcodeModule.view)
    }

    func showLogoutConfirmationAlert(completion: @escaping (() -> Void)) {
        let alertController = UIAlertController(
            title: TKLocales.Passcode.logoutConfirmationTitle,
            message: TKLocales.Passcode.logoutConfirmationDescription,
            preferredStyle: .alert
        )
        let cancelAction = UIAlertAction(title: TKLocales.Actions.cancel, style: .cancel)
        let logoutAction = UIAlertAction(title: TKLocales.SignOutWarning.title, style: .destructive) { _ in
            completion()
        }
        alertController.addAction(cancelAction)
        alertController.addAction(logoutAction)
        router.rootViewController.present(alertController, animated: true)
    }

    /// Re-creates the biometry-protected passcode item after a successful
    /// passcode validation, but only when it is actually needed: to lazily
    /// migrate a legacy biometryAny wrap key to biometryCurrentSet exactly once,
    /// or to restore biometric unlock after a re-enrollment invalidated the item.
    /// Re-encrypting on every unlock would be needless keychain churn on the hot
    /// transaction-confirmation path.
    func refreshBiometryProtectedPasscode(_ passcode: String) {
        let isEnabled = securityStore.getState().isBiometryEnable
        guard isEnabled else {
            return
        }
        let shouldRefresh = shouldRefreshBiometryProtectedPasscode()
        guard shouldRefresh else { return }
        do {
            try validator.refreshStoredPasscode(passcode)
        } catch {
            Log.e("Failed to refresh biometry-protected passcode", extraInfo: [
                "error": error.localizedDescription,
            ])
        }
    }

    /// `true` only when the costly re-encrypt + wrap-key recreation has a
    /// purpose: recovering an invalidated enrolled set, or performing the
    /// one-time biometryAny → biometryCurrentSet migration. Otherwise the stored
    /// item is already current and the unlock leaves it untouched.
    func shouldRefreshBiometryProtectedPasscode() -> Bool {
        let probe = validator.biometryAccessProbe()
        let migrated = validator.isBiometryItemMigrated()
        if probe == .invalidated {
            return true
        }
        return !migrated
    }

    /// Detects an enrollment removal when biometry is no longer usable at all.
    /// The auto-unlock path can't fire (the keyboard hides biometry), so nothing
    /// reads the protected item — this checks proactively and mirrors the
    /// unlock-failure classifier so a recoverable lockout never raises the alert.
    func showBiometryChangedAlertIfUnavailableInvalidated() {
        guard shouldDetectUnavailableBiometryChange else { return }
        guard securityStore.getState().isBiometryEnable else {
            return
        }

        let context = LAContext()
        var laError: NSError?
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &laError
        )
        // Biometry usable again → the auto-unlock path handles detection.
        guard !canEvaluate else { return }

        let failure = classifyBiometryUnlockFailure(
            status: errSecAuthFailed,
            canEvaluateBiometrics: false,
            isLockout: laError?.code == LAError.biometryLockout.rawValue,
            // Unused once biometry is unusable: the probe can't read a
            // biometry-protected item without any usable enrolled set.
            accessProbe: .indeterminate
        )
        guard case .invalidated = failure else { return }
        showBiometryChangedWarningIfNeeded()
    }

    var shouldDetectUnavailableBiometryChange: Bool {
        #if targetEnvironment(simulator)
            false
        #else
            true
        #endif
    }

    /// Whether biometry is enabled but its stored cache can no longer be
    /// satisfied (enrolled set changed). Non-interactive — the probe never
    /// prompts — so it is safe to call while deciding the keyboard button state.
    func isBiometryCacheInvalidated() -> Bool {
        guard securityStore.getState().isBiometryEnable else { return false }
        return validator.biometryAccessProbe() == .invalidated
    }

    func classifyBiometryFailure(_ error: Error) -> BiometryUnlockFailure {
        let status: OSStatus
        switch error {
        case let PasscodeStorageFailure.securityFailure(code):
            status = code
        case let TKKeychainError.other(code):
            status = code
        case PasscodeStorageFailure.notFound,
             TKKeychainError.noItem:
            // The biometry-protected passcode item read as not-found. On device a
            // biometryCurrentSet item invalidated by an enrollment change surfaces
            // this way; the classifier disambiguates it via the access probe.
            status = errSecItemNotFound
        default:
            return .other
        }

        let context = LAContext()
        var laError: NSError?
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &laError
        )
        let isLockout = laError?.code == LAError.biometryLockout.rawValue
        let probe = validator.biometryAccessProbe()
        return classifyBiometryUnlockFailure(
            status: status,
            canEvaluateBiometrics: canEvaluate,
            isLockout: isLockout,
            accessProbe: probe
        )
    }

    func showBiometryChangedWarningIfNeeded() {
        guard !didShowBiometryChangedWarning else {
            return
        }
        didShowBiometryChangedWarning = true
        var configuration = ToastPresenter.Configuration.defaultConfiguration(
            text: biometryChangedWarningText()
        )
        configuration.numberOfLines = 0
        configuration.dismissRule = .duration(4)
        configuration.allowsSwipeToDismiss = true
        ToastPresenter.showToast(configuration: configuration)
    }

    /// Picks Face ID / Touch ID specific copy from the device's biometry type,
    /// falling back to the generic wording when the type is unknown.
    func biometryChangedWarningText() -> String {
        let context = LAContext()
        // biometryType is only populated after a policy evaluation.
        _ = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: nil
        )
        switch context.biometryType {
        case .faceID:
            return TKLocales.Passcode.biometryChangedFaceIdDescription
        case .touchID:
            return TKLocales.Passcode.biometryChangedTouchIdDescription
        default:
            return TKLocales.Passcode.biometryChangedDescription
        }
    }
}

extension PasscodeInputCoordinator {
    static func present<ParentRouterViewController: UIViewController>(
        parentCoordinator: Coordinator,
        parentRouter: ContainerViewControllerRouter<ParentRouterViewController>,
        mnemonicAccess: MnemonicAccess,
        securityStore: SecurityStore,
        analyticsProvider: AnalyticsProvider? = nil,
        onCancel: @escaping () -> Void,
        onInput: @escaping (String) -> Void
    ) {
        present(
            parentCoordinator: parentCoordinator,
            parentRouter: parentRouter,
            validator: PasscodeConfirmationValidator(
                mnemonicAccess: mnemonicAccess
            ),
            securityStore: securityStore,
            analyticsProvider: analyticsProvider,
            onCancel: onCancel,
            onInput: onInput
        )
    }

    static func present<ParentRouterViewController: UIViewController>(
        parentCoordinator: Coordinator,
        parentRouter: ContainerViewControllerRouter<ParentRouterViewController>,
        validator: PasscodeInputValidator,
        securityStore: SecurityStore,
        analyticsProvider: AnalyticsProvider? = nil,
        onCancel: @escaping () -> Void,
        onInput: @escaping (String) -> Void
    ) {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()
        navigationController.modalPresentationStyle = .fullScreen
        navigationController.modalTransitionStyle = .crossDissolve

        let fromViewController: UIViewController = parentRouter.rootViewController.topPresentedViewController()

        let coordinator = PasscodeInputCoordinator(
            router: NavigationControllerRouter(
                rootViewController: navigationController
            ),
            context: .confirmation,
            validator: validator,
            biometryProvider: PasscodeBiometryProvider(
                biometryProvider: BiometryProvider(),
                securityStore: securityStore
            ),
            securityStore: securityStore,
            bruteForceController: PasscodeBruteForceController(
                securityStore: securityStore,
                analyticsProvider: analyticsProvider,
                from: .confirmation
            )
        )

        coordinator.didCancel = { [weak coordinator, weak parentCoordinator] in
            fromViewController.dismiss(animated: true) {
                parentCoordinator?.removeChild(coordinator)
                onCancel()
            }
        }

        coordinator.didInputPasscode = { [weak coordinator, weak parentCoordinator] passcode in
            fromViewController.dismiss(animated: true) {
                parentCoordinator?.removeChild(coordinator)
                onInput(passcode)
            }
        }

        parentCoordinator.addChild(coordinator)
        coordinator.start()

        fromViewController.present(
            navigationController,
            animated: true
        )
    }
}

extension PasscodeInputCoordinator {
    static func getPasscode<ParentRouterViewController: UIViewController>(
        parentCoordinator: Coordinator,
        parentRouter: ContainerViewControllerRouter<ParentRouterViewController>,
        mnemonicAccess: MnemonicAccess,
        securityStore: SecurityStore,
        analyticsProvider: AnalyticsProvider? = nil
    ) async -> String? {
        await getPasscode(
            parentCoordinator: parentCoordinator,
            parentRouter: parentRouter,
            validator: PasscodeConfirmationValidator(
                mnemonicAccess: mnemonicAccess
            ),
            securityStore: securityStore,
            analyticsProvider: analyticsProvider
        )
    }

    static func getPasscode<ParentRouterViewController: UIViewController>(
        parentCoordinator: Coordinator,
        parentRouter: ContainerViewControllerRouter<ParentRouterViewController>,
        validator: PasscodeInputValidator,
        securityStore: SecurityStore,
        analyticsProvider: AnalyticsProvider? = nil
    ) async -> String? {
        return await Task { @MainActor in
            return await withCheckedContinuation { continuation in
                PasscodeInputCoordinator.present(
                    parentCoordinator: parentCoordinator,
                    parentRouter: parentRouter,
                    validator: validator,
                    securityStore: securityStore,
                    analyticsProvider: analyticsProvider,
                    onCancel: {
                        continuation.resume(returning: nil)
                    },
                    onInput: {
                        continuation.resume(returning: $0)
                    }
                )
            }
        }.value
    }
}
