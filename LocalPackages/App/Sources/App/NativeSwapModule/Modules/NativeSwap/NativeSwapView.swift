import KeeperCore
import SnapKit
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

final class NativeSwapView: UIView {
    var didUpdateSendText: ((String) -> Void)?
    var didUpdateReceiveText: ((String) -> Void)?
    var didTapMax: (() -> Void)?
    var didTapSwap: (() -> Void)?
    var didTapClear: (() -> Void)?
    var didTapContinue: (() -> Void)?
    var didTapSendTokenPicker: (() -> Void)?
    var didTapReceiveTokenPicker: (() -> Void)?
    var didTapURL: ((URL) -> Void)? {
        didSet {
            updatePrivacyInfoView()
        }
    }

    let navigationBar = TKUINavigationBar()
    let titleView = TKUINavigationBarTitleView()

    private let titleSpacerView = UIView()
    private let sendView = NativeSwapSendView()
    private let receiveView = NativeSwapReceiveView()
    private let swapContainerView = UIView()
    private let swapButton = UIButton()
    private let rateStackView = UIStackView()
    private let rateABLabel = UILabel()
    private let rateBALabel = UILabel()
    private let continueButton = TKButton()
    private let processView = TKProcessContainerView()
    private lazy var privacyInfoHostingController: UIHostingController<NativeSwapPrivacyInfoView> = {
        let hostingController = UIHostingController(rootView: NativeSwapPrivacyInfoView())
        hostingController.view.backgroundColor = .clear
        return hostingController
    }()

    private var isSwapAnimating = false
    private var safeAreaBottomConstraint: Constraint?

    private var rateAB: String = "" {
        didSet {
            rateABLabel.attributedText = rateAB.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
        }
    }

    private var rateBA: String = "" {
        didSet {
            rateBALabel.attributedText = rateBA.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupBinding()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ state: NativeSwapViewModelImplementation.ViewState) {
        setSendTextFieldsFocus(state.isSendFocused)
        sendView.update(
            tokenAmount: state.sendAmount,
            remaining: state.remaining,
            tokenButton: state.sendTokenConfiguration,
            isShimmering: state.isSendShimmering,
            shouldShowMaxButton: state.sendTokenConfiguration.name != TonInfo.symbol // hide max button for TON
        )

        receiveView.update(
            tokenAmount: state.receiveAmount,
            tokenButton: state.receiveTokenConfiguration,
            isShimmering: state.isReceiveShimmering
        )

        rateAB = state.rateAB
        rateBA = state.rateBA
        rateStackView.isHidden = state.rateAB.isEmpty && state.rateBA.isEmpty

        continueButton.isHidden = state.state == .failed
        continueButton.isEnabled = state.isContinueButtonEnabled

        if state.state == .failed {
            processView.state = .failed
            processView.isHidden = false
        } else {
            processView.state = .idle
            processView.isHidden = true
        }
    }

    func setTextFieldsDelegate(_ delegate: UITextFieldDelegate?) {
        sendView.setTextFieldDelegate(delegate)
        receiveView.setTextFieldDelegate(delegate)
    }

    func setSendTextFieldsFocus(_ isSend: Bool) {
        if isSend {
            receiveView.setTextFieldState(.inactive)
            sendView.setTextFieldState(.active)
        } else {
            sendView.setTextFieldState(.inactive)
            receiveView.setTextFieldState(.active)
        }
    }

    private func setup() {
        navigationBar.leftViews = [titleView]

        swapContainerView.clipsToBounds = false

        processView.state = .idle
        processView.isHidden = true

        setupRateStackView()
        setupSwapButton()
        setupContinueButton()

        setupConstraints()

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    private func setupRateStackView() {
        rateStackView.axis = .vertical
        rateStackView.spacing = 0
        rateStackView.alignment = .center
        rateStackView.addArrangedSubview(rateABLabel)
        rateStackView.addArrangedSubview(rateBALabel)
        rateStackView.isHidden = true
    }

    private func setupSwapButton() {
        var swapButtonConfiguration = UIButton.Configuration.filled()
        swapButtonConfiguration.image = .TKUIKit.Icons.Size16.swapVertical
        swapButtonConfiguration.imageColorTransformer = UIConfigurationColorTransformer { _ in
            .Button.tertiaryForeground
        }
        swapButtonConfiguration.background.backgroundColor = .Button.tertiaryBackground
        swapButtonConfiguration.background.backgroundInsets = NSDirectionalEdgeInsets(
            top: 4,
            leading: 4,
            bottom: 4,
            trailing: 4
        )
        swapButtonConfiguration.cornerStyle = .capsule

        swapButton.configuration = swapButtonConfiguration
        swapButton.configurationUpdateHandler = { button in
            switch button.state {
            case .selected, .highlighted:
                button.configuration?.background.backgroundColor = .Button.tertiaryBackgroundHighlighted
            case .disabled:
                button.configuration?.background.backgroundColor = .Button.tertiaryBackgroundDisabled
            default:
                button.configuration?.background.backgroundColor = .Button.tertiaryBackground
            }
        }
        swapButton.addAction(
            UIAction { [weak self] _ in
                guard let self, !isSwapAnimating else { return }

                isSwapAnimating = true
                didTapSwap?()

                UIView.animate(withDuration: 0.2) {
                    self.swapButton.transform = self.swapButton.transform == .identity ? CGAffineTransform(rotationAngle: .pi) : .identity
                } completion: { _ in
                    self.isSwapAnimating = false
                }
            },
            for: .touchUpInside
        )
    }

    private func setupContinueButton() {
        var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: .primary,
            size: .large
        )
        continueButtonConfiguration.isEnabled = false
        continueButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.Actions.continueAction)
        )
        continueButtonConfiguration.action = { [weak self] in
            self?.didTapContinue?()
        }
        continueButton.configuration = continueButtonConfiguration
    }

    private func setupConstraints() {
        addSubview(navigationBar)
        addSubview(sendView)
        addSubview(receiveView)
        addSubview(swapContainerView)
        addSubview(swapButton)
        addSubview(rateStackView)
        addSubview(continueButton)
        addSubview(processView)
        addSubview(privacyInfoHostingController.view)

        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
        }

        sendView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.left.right.equalTo(self).inset(16)
            make.height.equalTo(96)
        }

        swapContainerView.snp.makeConstraints { make in
            make.top.equalTo(sendView.snp.bottom)
            make.height.equalTo(8)
            make.left.right.equalTo(self).inset(16)
        }

        swapButton.snp.makeConstraints { make in
            make.center.equalTo(swapContainerView.snp.center)
            make.size.equalTo(48)
        }

        receiveView.snp.makeConstraints { make in
            make.top.equalTo(swapContainerView.snp.bottom)
            make.left.right.equalTo(self).inset(16)
            make.height.equalTo(104)
        }

        rateStackView.snp.makeConstraints { make in
            make.top.equalTo(receiveView.snp.bottom).offset(12)
            make.left.right.equalTo(self).inset(16)
        }

        continueButton.snp.makeConstraints { make in
            make.left.right.equalTo(self).inset(16)
            safeAreaBottomConstraint = make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(16).constraint
        }

        processView.snp.makeConstraints { make in
            make.center.equalTo(continueButton.snp.center)
        }

        privacyInfoHostingController.view.snp.makeConstraints {
            $0.left.right.equalTo(self).inset(16)
            $0.bottom.equalTo(continueButton.snp.top).inset(-16)
        }
    }

    private func setupBinding() {
        sendView.didUpdateText = { [weak self] text in
            self?.didUpdateSendText?(text)
        }

        receiveView.didUpdateText = { [weak self] text in
            self?.didUpdateReceiveText?(text)
        }

        sendView.didTapMax = { [weak self] in
            self?.didTapMax?()
        }

        sendView.didTapTokenPicker = { [weak self] in
            self?.didTapSendTokenPicker?()
        }

        receiveView.didTapTokenPicker = { [weak self] in
            self?.didTapReceiveTokenPicker?()
        }

        sendView.didTapClear = { [weak self] in
            self?.didTapClear?()
        }

        receiveView.didTapClear = { [weak self] in
            self?.didTapClear?()
        }
    }

    override func hitTest(
        _ point: CGPoint,
        with event: UIEvent?
    ) -> UIView? {
        let expandedButtonFrame = swapButton.frame.insetBy(dx: -4, dy: -4)

        return expandedButtonFrame.contains(point) ? swapButton : super.hitTest(point, with: event)
    }

    private func updatePrivacyInfoView() {
        privacyInfoHostingController.rootView = NativeSwapPrivacyInfoView(onURLTap: didTapURL)
    }

    @objc
    private func adjustForKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = convert(keyboardScreenEndFrame, from: window)

        UIView.animate(withDuration: 0.3) {
            if notification.name == UIResponder.keyboardWillHideNotification {
                self.safeAreaBottomConstraint?.update(inset: 16)
            } else {
                self.safeAreaBottomConstraint?.update(inset: keyboardViewEndFrame.height - self.safeAreaInsets.bottom + 16)
            }

            self.layoutIfNeeded()
        }
    }
}
