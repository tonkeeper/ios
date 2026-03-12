import SnapKit
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct NativeSwapTransactionConfirmationContainerPopUpItem: TKPopUp.Item {
    let configuration: NativeSwapTransactionConfirmationContainerView.Configuration
    let bottomSpace: CGFloat
    func getView() -> UIView {
        let view = NativeSwapTransactionConfirmationContainerView()
        view.configuration = configuration
        return view
    }
}

final class NativeSwapTransactionConfirmationContainerView: UIView {
    struct Configuration {
        let sendAmount: String
        let receiveAmount: String
        let didAvailableExtraTypes: Bool
        let rate: Configuration.Item
        let fee: Configuration.Item
        let provider: Configuration.Item
        let slippage: Configuration.Item
        let didTapEdit: ((Bool) -> Void)?
        let didTapFeeType: ((UIView) -> Void)?
        let didTapSlippageInfo: (() -> Void)?
        let tradeStartDeadline: Date?
        let didTimerFinished: (() -> Void)?

        struct Item {
            let title: String
            let value: String
        }
    }

    var configuration: NativeSwapTransactionConfirmationContainerView.Configuration? {
        didSet {
            didUpdateConfiguration()
        }
    }

    private let sendView = NativeSwapTransactionConfirmationSendView()
    private let arrowContainerView = UIView()
    private let arrowButton = UIButton()
    private let receiveContainerView = UIView()
    private let receiveView = NativeSwapTransactionConfirmationReceiveView()
    private let rateView = NativeSwapTransactionConfirmationItemView()
    private let feeView = NativeSwapTransactionConfirmationItemView()
    private let providerView = NativeSwapTransactionConfirmationItemView()
    private let slippageView = NativeSwapTransactionConfirmationItemView()
    private let expireView = NativeSwapTransactionConfirmationItemView()

    private var timer: Timer?

    init() {
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    private func setup() {
        arrowContainerView.clipsToBounds = false

        sendView.backgroundColor = .Background.content
        sendView.layer.cornerRadius = 16
        sendView.clipsToBounds = true

        receiveView.backgroundColor = .Background.content
        receiveView.layer.cornerRadius = 16
        receiveView.clipsToBounds = true

        receiveContainerView.backgroundColor = .Background.content
        receiveContainerView.layer.cornerRadius = 16
        receiveContainerView.clipsToBounds = true

        setupArrowButton()

        setupConstraints()
    }

    private func setupArrowButton() {
        var arrowButtonConfiguration = UIButton.Configuration.filled()
        arrowButtonConfiguration.image = .TKUIKit.Icons.Size16.arrowDown
        arrowButtonConfiguration.imageColorTransformer = UIConfigurationColorTransformer { _ in
            .Button.tertiaryForeground
        }
        arrowButtonConfiguration.background.backgroundColor = .Button.tertiaryBackground
        arrowButtonConfiguration.background.backgroundInsets = NSDirectionalEdgeInsets(
            top: 4,
            leading: 4,
            bottom: 4,
            trailing: 4
        )
        arrowButtonConfiguration.cornerStyle = .capsule

        arrowButton.configuration = arrowButtonConfiguration
        arrowButton.isUserInteractionEnabled = false
    }

    private func setupConstraints() {
        addSubview(sendView)
        addSubview(arrowContainerView)
        addSubview(arrowButton)
        addSubview(receiveContainerView)
        addSubview(receiveView)

        bringSubviewToFront(arrowButton)

        receiveContainerView.addSubview(rateView)
        receiveContainerView.addSubview(feeView)
        receiveContainerView.addSubview(providerView)
        receiveContainerView.addSubview(slippageView)
        receiveContainerView.addSubview(expireView)

        sendView.snp.makeConstraints { make in
            make.top.equalTo(self)
            make.left.right.equalTo(self)
        }

        arrowContainerView.snp.makeConstraints { make in
            make.top.equalTo(sendView.snp.bottom)
            make.height.equalTo(8)
            make.left.right.equalTo(self)
        }

        arrowButton.snp.makeConstraints { make in
            make.centerY.equalTo(arrowContainerView.snp.centerY)
            make.right.equalTo(arrowContainerView.snp.right).inset(24)
            make.size.equalTo(48)
        }

        receiveView.snp.makeConstraints { make in
            make.top.equalTo(sendView.snp.bottom).inset(-8)
            make.left.right.equalTo(self)
        }

        receiveContainerView.snp.makeConstraints { make in
            make.top.equalTo(receiveView.snp.bottom).inset(-8)
            make.left.right.equalTo(self)
            make.bottom.equalTo(self)
        }

        rateView.snp.makeConstraints { make in
            make.top.equalTo(receiveContainerView).inset(8)
            make.left.right.equalTo(receiveContainerView)
            make.height.equalTo(36)
        }

        slippageView.snp.makeConstraints { make in
            make.top.equalTo(rateView.snp.bottom)
            make.left.right.equalTo(receiveContainerView)
            make.height.equalTo(36)
        }

        feeView.snp.makeConstraints { make in
            make.top.equalTo(slippageView.snp.bottom)
            make.left.right.equalTo(receiveContainerView)
            make.height.equalTo(36)
        }

        providerView.snp.makeConstraints { make in
            make.top.equalTo(feeView.snp.bottom)
            make.left.right.equalTo(receiveContainerView)
            make.height.equalTo(36)
        }

        expireView.snp.makeConstraints { make in
            make.top.equalTo(providerView.snp.bottom)
            make.left.right.equalTo(receiveContainerView)
            make.height.equalTo(36)
            make.bottom.equalTo(receiveContainerView).inset(8)
        }
    }

    private func didUpdateConfiguration() {
        guard let configuration else { return }

        sendView.update(amount: configuration.sendAmount)
        receiveView.update(amount: configuration.receiveAmount)

        rateView.update(
            title: configuration.rate.title,
            value: configuration.rate.value
        )
        feeView.update(
            title: configuration.fee.title,
            value: configuration.fee.value,
            captionModel: configuration.didAvailableExtraTypes ? TKPlainButton.Model(
                title: TKLocales.NativeSwap.Confirm.Actions.edit.withTextStyle(
                    .body2,
                    color: .Text.accent
                ),
                action: { [weak self] in
                    guard let sourceView = self?.feeView.captionButton else { return }

                    configuration.didTapFeeType?(sourceView)
                }
            ) : nil
        )
        providerView.update(
            title: configuration.provider.title,
            value: configuration.provider.value
        )

        slippageView.update(
            title: configuration.slippage.title,
            value: configuration.slippage.value,
            captionModel: .init(
                title: nil,
                icon: TKPlainButton.Model.Icon(
                    image: .TKUIKit.Icons.Size16.informationCircle,
                    tintColor: .Icon.secondary,
                    padding: .zero
                ),
                action: {
                    configuration.didTapSlippageInfo?()
                }
            )
        )

        setTradeStartDeadline(
            configuration.tradeStartDeadline,
            didTimerFinished: configuration.didTimerFinished
        )

        sendView.didTapEdit = {
            configuration.didTapEdit?(true)
        }

        receiveView.didTapEdit = {
            configuration.didTapEdit?(false)
        }
    }

    private func setTradeStartDeadline(_ deadline: Date?, didTimerFinished: (() -> Void)? = nil) {
        guard let deadline else { return }
        timer?.invalidate()
        timer = nil

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateProgress(deadline: deadline, didTimerFinished: didTimerFinished)
            }
        }
        RunLoop.main.add(timer, forMode: .common)

        self.timer = timer

        updateProgress(deadline: deadline, didTimerFinished: didTimerFinished)
    }

    private func updateProgress(deadline: Date, didTimerFinished: (() -> Void)? = nil) {
        let remainingTime = deadline.timeIntervalSince(Date())

        if remainingTime <= 0 {
            timer?.invalidate()
            timer = nil

            didTimerFinished?()
            return
        }

        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        let formatted = "\(minutes):" + String(format: "%02d", seconds)

        expireView.update(title: TKLocales.NativeSwap.Screen.Confirm.Field.expires, value: formatted)
    }
}
