import SnapKit
import TKUIKit
import UIKit

final class BalanceHeaderBalanceAmountView: UIView {
    struct Configuration {
        struct BackupButton {
            let color: UIColor
            let action: (() -> Void)?
        }

        let amountButtonConfiguration: BalanceHeaderBalanceAmountButton.Configuration
        let batteryButtonConfiguration: BalanceHeaderBalanceBatteryButton.Configuration?
        let backupButton: BackupButton?
    }

    var configuration: Configuration? {
        didSet {
            didUpdateConfiguration()
        }
    }

    private let amountButton = BalanceHeaderBalanceAmountButton()
    private let batteryButton = BalanceHeaderBalanceBatteryButton()
    private let backupButton = TKButton()
    private let stackView = UIStackView()
    private let containerView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 56)
    }

    private func setup() {
        setupBackupButton()

        stackView.axis = .horizontal
        stackView.alignment = .center

        addSubview(containerView)
        containerView.addSubview(stackView)
        stackView.addArrangedSubview(amountButton)
        stackView.addArrangedSubview(batteryButton)
        stackView.setCustomSpacing(8, after: amountButton)
        stackView.addArrangedSubview(backupButton)

        containerView.snp.makeConstraints { make in
            make.left.greaterThanOrEqualTo(self)
            make.right.lessThanOrEqualTo(self)
            make.top.bottom.equalTo(self)
        }

        stackView.snp.makeConstraints { make in
            make.left.greaterThanOrEqualTo(containerView)
            make.right.lessThanOrEqualTo(containerView)
            make.center.equalTo(containerView)
        }
    }

    private func didUpdateConfiguration() {
        guard let configuration = configuration else {
            return
        }
        amountButton.configuration = configuration.amountButtonConfiguration

        if let batteryButtonConfiguration = configuration.batteryButtonConfiguration {
            batteryButton.isHidden = false
            batteryButton.configuration = batteryButtonConfiguration
        } else {
            batteryButton.isHidden = true
        }

        if let backupButtonConfiguration = configuration.backupButton {
            backupButton.configuration.iconTintColor = backupButtonConfiguration.color
            backupButton.configuration.action = backupButtonConfiguration.action
            backupButton.configuration.backgroundColors = [
                .normal: backupButtonConfiguration.color.withAlphaComponent(0.48),
                .highlighted: backupButtonConfiguration.color.withAlphaComponent(0.48),
            ]
            backupButton.isHidden = false
        } else {
            backupButton.isHidden = true
        }

        stackView.snp.remakeConstraints { make in
            make.left.greaterThanOrEqualTo(containerView)
            make.right.lessThanOrEqualTo(containerView)
            make.center.equalTo(containerView)
        }
    }

    private func setupBackupButton() {
        backupButton.configuration.content = TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size12.informationCircle)
        backupButton.configuration.backgroundColors = [.normal: .Accent.orange.withAlphaComponent(0.48),
                                                       .highlighted: .Accent.orange.withAlphaComponent(0.48)]
        backupButton.configuration.contentPadding = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        backupButton.configuration.padding = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 10)
        backupButton.configuration.cornerRadius = 10
        backupButton.configuration.iconTintColor = .Accent.orange
        backupButton.configuration.contentAlpha = [.highlighted: 0.48]

        backupButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        backupButton.isHidden = true
    }
}
