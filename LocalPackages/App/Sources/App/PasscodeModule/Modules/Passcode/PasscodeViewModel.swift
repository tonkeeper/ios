import TKUIKit
import UIKit

protocol PasscodeModuleOutput: AnyObject {
    var biometryProvider: (() async -> TKKeyboardView.Biometry)? { get set }
    var didTapDigit: ((Int) -> Void)? { get set }
    var didTapBackspace: (() -> Void)? { get set }
    var didTapBiometry: (() -> Void)? { get set }
}

protocol PasscodeModuleInput: AnyObject {
    /// Re-query biometry and refresh the keypad button. When `autoPrompt` is true, also trigger it
    /// immediately. Called with `true` on load; with `false` when a lockout ends so the button is just
    /// re-activated without forcing a prompt. (TK-1472)
    func evaluateBiometry(autoPrompt: Bool)
}

protocol PasscodeViewModel: AnyObject {
    var didUpdateBiometry: ((TKKeyboardView.Biometry) -> Void)? { get set }

    func viewDidLoad()
    func didTapDigitButton(_ digit: Int)
    func didTapBackspaceButton()
    func didTapBiometryButton()
}

final class PasscodeViewModelImplementation: PasscodeViewModel, PasscodeModuleOutput, PasscodeModuleInput {
    // MARK: - PasscodeModuleOutput

    var biometryProvider: (() async -> TKKeyboardView.Biometry)?
    var didTapDigit: ((Int) -> Void)?
    var didTapBackspace: (() -> Void)?
    var didTapBiometry: (() -> Void)?

    // MARK: - PasscodeModuleInput

    // MARK: - PasscodeViewModel

    var didUpdateBiometry: ((TKKeyboardView.Biometry) -> Void)?

    func viewDidLoad() {
        evaluateBiometry(autoPrompt: true)
    }

    func evaluateBiometry(autoPrompt: Bool) {
        Task {
            let biometry = await biometryProvider?() ?? .none
            await MainActor.run {
                didUpdateBiometry?(biometry)
                guard autoPrompt else { return }
                switch biometry {
                case .faceId, .touchId:
                    didTapBiometryButton()
                default:
                    break
                }
            }
        }
    }

    func didTapDigitButton(_ digit: Int) {
        didTapDigit?(digit)
    }

    func didTapBackspaceButton() {
        didTapBackspace?()
    }

    func didTapBiometryButton() {
        didTapBiometry?()
    }
}
