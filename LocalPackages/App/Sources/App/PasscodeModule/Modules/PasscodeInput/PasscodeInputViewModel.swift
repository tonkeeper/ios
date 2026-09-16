import Foundation
import TKUIKit
import UIKit

enum PasscodeInputValidationResult {
    case success
    case failed
    case none
}

enum PasscodeInputResult {
    case success
    case none
    /// - attemptsLeft: attempts remaining before the next lockout, or `nil` to keep the counter hidden.
    /// - lockoutUntil: end date of a lockout triggered by this attempt, or `nil` if none was triggered.
    case failed(attemptsLeft: Int?, lockoutUntil: Date?)

    /// Plain failed verdict with no brute-force hints — for flows without lockout protection (create/change).
    static let failed = PasscodeInputResult.failed(attemptsLeft: nil, lockoutUntil: nil)
}

protocol PasscodeInputModuleOutput: AnyObject {
    var validateInput: ((String) async -> PasscodeInputResult)? { get set }
    var didFinish: ((String) -> Void)? { get set }
    var didFailed: (() -> Void)? { get set }
    var didUpdateKeyboardEnabled: ((Bool) -> Void)? { get set }
    /// Fired when an active lockout ends (countdown hits 0, or the screen reappears after it expired).
    /// Lets the host re-request biometry first, matching the pre-lockout state. (TK-1472)
    var didEndLockout: (() -> Void)? { get set }
}

protocol PasscodeInputModuleInput: AnyObject {
    func didTapDigit(_ digit: Int)
    func didTapBackspace()
    func didSetInput(_ input: String)
}

protocol PasscodeInputViewModel: AnyObject {
    var didUpdateTitle: ((String?) -> Void)? { get set }
    var didUpdateState: ((PasscodeInputView.State, (() -> Void)?) -> Void)? { get set }

    func viewDidLoad()
    func viewWillAppear()
    func viewDidDisappear()
}

final class PasscodeInputViewModelImplementation: PasscodeInputViewModel, PasscodeInputModuleInput, PasscodeInputModuleOutput {
    // MARK: - PasscodeInputModuleOutput

    var validateInput: ((String) async -> PasscodeInputResult)?
    var didFinish: ((String) -> Void)?
    var didFailed: (() -> Void)?
    var didUpdateKeyboardEnabled: ((Bool) -> Void)?
    var didEndLockout: (() -> Void)?

    // MARK: - PasscodeInputModuleInput

    func didTapDigit(_ digit: Int) {
        guard isInputEnable else { return }
        input += "\(digit)"
        didUpdateInput()
    }

    func didTapBackspace() {
        guard isInputEnable else { return }
        input = String(input.dropLast(1))
        didUpdateInput()
    }

    func didSetInput(_ input: String) {
        guard isInputEnable else { return }
        self.input = input
        didUpdateInput()
    }

    // MARK: - PasscodeInputViewModel

    var didUpdateTitle: ((String?) -> Void)?
    var didUpdateState: ((PasscodeInputView.State, (() -> Void)?) -> Void)?

    func viewDidLoad() {
        input = ""
        didUpdateTitle?(title)
    }

    func viewWillAppear() {
        // Re-arm the lockout (and its countdown) whenever the screen appears — covers the initial
        // presentation as well as returning to a screen whose lockout is still active.
        guard let lockoutUntil else { return }
        if lockoutUntil > Date() {
            enterLockout(until: lockoutUntil)
        } else {
            exitLockout()
        }
    }

    func viewDidDisappear() {
        lockoutTimer?.invalidate()
        lockoutTimer = nil
        input = ""
        // Keep showing the lockout when leaving while still locked; only reset the normal input.
        if lockoutUntil == nil {
            didUpdateState?(.input(0), nil)
        }
    }

    // MARK: - State

    private var input = ""
    private var isInputEnable = true
    private var lockoutTimer: Timer?
    private var lockoutUntil: Date?

    // MARK: - Dependencies

    private let title: String

    init(title: String, initialLockoutUntil: Date? = nil) {
        self.title = title
        self.lockoutUntil = initialLockoutUntil
        // Start disabled when presented already locked, so a racing biometry auto-fill (or any input)
        // can't slip through before `viewWillAppear` arms the lockout. See TK-1472.
        self.isInputEnable = !(initialLockoutUntil.map { $0 > Date() } ?? false)
    }

    deinit {
        lockoutTimer?.invalidate()
    }
}

private extension PasscodeInputViewModelImplementation {
    func didUpdateInput() {
        let input = input
        let inputCount = input.count

        switch inputCount {
        case 0 ..< Int.passcodeLength:
            didUpdateState?(.input(inputCount), nil)
        case Int.passcodeLength:
            didUpdateState?(.input(inputCount), nil)

            isInputEnable = false
            guard let validateInput else {
                isInputEnable = true
                return
            }
            Task {
                let result = await validateInput(input)
                await MainActor.run {
                    self.handle(result: result, inputCount: inputCount, input: input)
                }
            }
        default:
            break
        }
    }

    func handle(result: PasscodeInputResult, inputCount: Int, input: String) {
        let finishInput = { [weak self] in
            self?.isInputEnable = true
            self?.didFinish?(input)
            self?.input = ""
        }

        switch result {
        case .success:
            didUpdateState?(.success, finishInput)
        case .none:
            didUpdateState?(.input(inputCount), finishInput)
        case let .failed(attemptsLeft, lockoutUntil):
            didUpdateState?(.failed(inputCount, attemptsLeft: attemptsLeft, willLockout: lockoutUntil != nil)) { [weak self] in
                guard let self else { return }
                self.input = ""
                if let lockoutUntil {
                    self.enterLockout(until: lockoutUntil)
                } else {
                    self.isInputEnable = true
                    self.didFailed?()
                }
            }
        }
    }

    func enterLockout(until: Date) {
        lockoutUntil = until
        input = ""
        isInputEnable = false
        didUpdateKeyboardEnabled?(false)
        lockoutTimer?.invalidate()
        updateLockoutState(until: until)
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateLockoutState(until: until)
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        lockoutTimer = timer
    }

    func updateLockoutState(until: Date) {
        let remaining = Int(ceil(until.timeIntervalSinceNow))
        if remaining <= 0 {
            exitLockout()
        } else {
            didUpdateState?(.lockout(remainingSeconds: remaining), nil)
        }
    }

    func exitLockout() {
        lockoutUntil = nil
        lockoutTimer?.invalidate()
        lockoutTimer = nil
        input = ""
        isInputEnable = true
        didUpdateKeyboardEnabled?(true)
        didUpdateState?(.input(0), nil)
        // Only reached after a real lockout: re-request biometry first, like the pre-lockout state. (TK-1472)
        didEndLockout?()
    }
}

private extension Int {
    static let passcodeLength = 4
}
