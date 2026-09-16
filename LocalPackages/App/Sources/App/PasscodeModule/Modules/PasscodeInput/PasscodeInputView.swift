import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class PasscodeInputView: UIView {
    enum State {
        case input(Int)
        case failed(Int, attemptsLeft: Int?, willLockout: Bool)
        case success
        case lockout(remainingSeconds: Int)
    }

    var title: String? {
        didSet {
            titleLabel.attributedText = title?.withTextStyle(
                .h3,
                color: .Text.primary,
                alignment: .center
            )
        }
    }

    let passcodeView = PasscodeDotRowView()
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let topContainer = UIView()
    let stackView = UIStackView()

    private let lockoutStackView = UIStackView()
    private let lockoutIconContainer = UIView()
    private let lockoutIconView = UIImageView()
    private let lockoutTitleLabel = UILabel()
    private let lockoutSubtitleLabel = UILabel()

    private let errorFeedbackGenerator = UINotificationFeedbackGenerator()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setState(_ state: State, completion: (() -> Void)?) {
        passcodeView.layer.removeAllAnimations()
        switch state {
        case let .input(count):
            showLockout(false)
            // Keep the "N attempts left" hint while the user re-enters a code; clear it only on a true
            // reset to empty (fresh prompt, post-lockout, full backspace). The next verdict replaces it. (TK-1472)
            if count == 0 {
                updateAttemptsSubtitle(nil)
            }
            passcodeView.inputCount = count
            passcodeView.validationState = .none
            completion?()
        case let .failed(count, attemptsLeft, willLockout):
            showLockout(false)
            updateAttemptsSubtitle(attemptsLeft)
            passcodeView.validationState = .failed
            triggerErrorHaptic()
            shakeDots { [weak self] in
                guard let self else { return }
                // A failure that triggers a lockout skips the dot-drain animation and hands off to the
                // lockout placeholder immediately — red dots, shake, then lockout. (TK-1472)
                if willLockout {
                    completion?()
                } else {
                    self.reset(inputCount: count, completion: completion)
                }
            }
        case .success:
            showLockout(false)
            passcodeView.validationState = .success
            completion?()
        case let .lockout(remainingSeconds):
            updateLockout(remainingSeconds: remainingSeconds)
            showLockout(true)
            completion?()
        }
    }

    private func reset(inputCount: Int, completion: (() -> Void)?) {
        var count = inputCount
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
            count -= 1
            self?.passcodeView.inputCount = count
            self?.passcodeView.validationState = .failed
            if count < 0 {
                timer.invalidate()
                completion?()
            }
        }
    }

    private func triggerErrorHaptic() {
        errorFeedbackGenerator.notificationOccurred(.error)
    }

    private func showLockout(_ show: Bool) {
        lockoutStackView.isHidden = !show
        stackView.isHidden = show
    }

    private func updateAttemptsSubtitle(_ attemptsLeft: Int?) {
        guard let attemptsLeft, attemptsLeft > 0 else {
            subtitleLabel.attributedText = nil
            subtitleLabel.isHidden = true
            return
        }
        let text = attemptsLeft == 1
            ? TKLocales.Passcode.attemptLeft
            : TKLocales.Passcode.attemptsLeft(attemptsLeft)
        subtitleLabel.attributedText = text.withTextStyle(
            .body1,
            color: .Text.secondary,
            alignment: .center
        )
        subtitleLabel.isHidden = false
    }

    private func updateLockout(remainingSeconds: Int) {
        lockoutTitleLabel.attributedText = TKLocales.Passcode.tooManyAttempts.withTextStyle(
            .h3,
            color: .Text.primary,
            alignment: .center
        )
        lockoutSubtitleLabel.attributedText = lockoutSubtitle(remainingSeconds: max(0, remainingSeconds))
    }

    private func lockoutSubtitle(remainingSeconds: Int) -> NSAttributedString {
        let timeString = String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
        let fullString = TKLocales.Passcode.tryAgainIn(timeString)
        let attributed = NSMutableAttributedString(
            attributedString: fullString.withTextStyle(
                .body1,
                color: .Text.secondary,
                alignment: .center
            )
        )
        let timeRange = (fullString as NSString).range(of: timeString)
        if timeRange.location != NSNotFound {
            attributed.addAttributes(
                [
                    .foregroundColor: UIColor.Text.primary,
                    .font: TKTextStyle.body1.font.monospacedDigits(),
                ],
                range: timeRange
            )
        }
        return attributed
    }

    private func shakeDots(completion: @escaping () -> Void) {
        let passcodeViewCenter = passcodeView.center
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = .dotsShakeAnimationDuration
        animation.repeatCount = .dotsShakeAnimationRepeatCount
        animation.autoreverses = true
        animation.fromValue = NSValue(
            cgPoint: CGPoint(
                x: passcodeViewCenter.x - .dotsShakeAnimationPositionDiff,
                y: passcodeViewCenter.y
            )
        )
        animation.toValue = NSValue(
            cgPoint: CGPoint(
                x: passcodeViewCenter.x + .dotsShakeAnimationPositionDiff,
                y: passcodeViewCenter.y
            )
        )
        CATransaction.setCompletionBlock {
            completion()
        }

        passcodeView.layer.add(animation, forKey: nil)
        CATransaction.commit()
    }
}

private extension PasscodeInputView {
    func setup() {
        backgroundColor = .Background.page

        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = .titleBottomSpace

        subtitleLabel.numberOfLines = 0
        subtitleLabel.isHidden = true

        setupLockoutView()

        addSubview(topContainer)
        topContainer.addSubview(stackView)
        topContainer.addSubview(lockoutStackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(passcodeView)
        stackView.addArrangedSubview(subtitleLabel)

        lockoutStackView.isHidden = true

        setupConstraints()
    }

    func setupLockoutView() {
        lockoutStackView.axis = .vertical
        lockoutStackView.alignment = .center
        lockoutStackView.spacing = .lockoutTextSpace

        lockoutIconContainer.backgroundColor = .Background.content
        lockoutIconContainer.layer.cornerRadius = .lockoutIconSide / 2
        lockoutIconView.image = .TKUIKit.Icons.Size28.lock.withRenderingMode(.alwaysTemplate)
        lockoutIconView.tintColor = .Icon.secondary
        lockoutIconView.contentMode = .scaleAspectFit
        lockoutIconContainer.addSubview(lockoutIconView)

        lockoutTitleLabel.numberOfLines = 0
        lockoutSubtitleLabel.numberOfLines = 0

        lockoutStackView.addArrangedSubview(lockoutIconContainer)
        lockoutStackView.setCustomSpacing(.lockoutIconBottomSpace, after: lockoutIconContainer)
        lockoutStackView.addArrangedSubview(lockoutTitleLabel)
        lockoutStackView.addArrangedSubview(lockoutSubtitleLabel)
    }

    func setupConstraints() {
        topContainer.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.left.bottom.right.equalTo(self)

            stackView.snp.makeConstraints { make in
                make.center.equalTo(topContainer)
            }

            lockoutStackView.snp.makeConstraints { make in
                make.center.equalTo(topContainer)
                make.left.greaterThanOrEqualTo(topContainer).offset(32)
                make.right.lessThanOrEqualTo(topContainer).inset(32)
            }
        }

        lockoutIconContainer.snp.makeConstraints { make in
            make.size.equalTo(CGFloat.lockoutIconSide)
        }
        lockoutIconView.snp.makeConstraints { make in
            make.center.equalTo(lockoutIconContainer)
            make.size.equalTo(CGFloat.lockoutIconGlyphSide)
        }
    }
}

private extension CGFloat {
    static let titleBottomSpace: CGFloat = 20
    static let dotsShakeAnimationPositionDiff: CGFloat = 10
    static let lockoutTextSpace: CGFloat = 4
    static let lockoutIconBottomSpace: CGFloat = 16
    static let lockoutIconSide: CGFloat = 84
    static let lockoutIconGlyphSide: CGFloat = 28
}

private extension TimeInterval {
    static let dotsShakeAnimationDuration: TimeInterval = 0.07
}

private extension Float {
    static let dotsShakeAnimationRepeatCount: Float = 3
}
