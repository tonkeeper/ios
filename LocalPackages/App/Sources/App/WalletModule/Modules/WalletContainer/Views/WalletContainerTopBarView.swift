import SnapKit
import TKUIKit
import UIKit

final class WalletContainerTopBarView: UIView, ConfigurableView {
    var isSeparatorHidden = true {
        didSet { separatorView.isHidden = isSeparatorHidden }
    }

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .Separator.common
        view.isHidden = true
        return view
    }()

    private let contentContainerView = UIView()
    let walletButton = WalletContainerWalletButton()
    private let supportButton = TKButton(frame: .zero)
    private let settingsButton = TKIndicatorButton(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        struct SettingsButtonModel {
            let configuration: TKButton.Configuration
            let isIndicatorVisible: Bool
        }

        let walletButtonConfiguration: WalletContainerWalletButton.Model
        let supportButtonConfiguration: TKButton.Configuration
        let settingButtonConfiguration: SettingsButtonModel
    }

    func configure(model: Model) {
        walletButton.configure(model: model.walletButtonConfiguration)
        supportButton.configuration = model.supportButtonConfiguration
        settingsButton.configuration = model.settingButtonConfiguration.configuration
        settingsButton.configureIndicatorVisibility(model.settingButtonConfiguration.isIndicatorVisible)
    }
}

private extension WalletContainerTopBarView {
    func setup() {
        backgroundColor = .Background.page

        addSubview(contentContainerView)
        addSubview(separatorView)
        contentContainerView.addSubview(supportButton)
        contentContainerView.addSubview(settingsButton)
        contentContainerView.addSubview(walletButton)
        setupConstraints()
    }

    func setupConstraints() {
        supportButton.setContentHuggingPriority(.required, for: .horizontal)
        supportButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        settingsButton.setContentHuggingPriority(.required, for: .horizontal)
        settingsButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        walletButton.snp.makeConstraints { make in
            make.centerX.equalTo(contentContainerView)
            make.centerY.equalTo(contentContainerView)
            make.right.lessThanOrEqualTo(settingsButton.snp.left)
        }

        contentContainerView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.left.right.bottom.equalTo(self)
            make.height.equalTo(64)
        }

        supportButton.snp.makeConstraints { make in
            make.left.equalTo(contentContainerView).inset(CGFloat.supportButtonLeftInset)
            make.centerY.equalTo(contentContainerView)
        }

        settingsButton.snp.makeConstraints { make in
            make.right.equalTo(contentContainerView).inset(CGFloat.settingsButtonRightInset)
            make.centerY.equalTo(contentContainerView)
        }

        separatorView.snp.makeConstraints { make in
            make.left.right.equalTo(self)
            make.bottom.equalTo(self)
            make.height.equalTo(TKUIKit.Constants.separatorWidth)
        }
    }
}

private extension CGFloat {
    static let walletButtonTopInset: CGFloat = 12
    static let walletButtonBottomInset: CGFloat = 12
    static let supportButtonLeftInset: CGFloat = 8
    static let settingsButtonRightInset: CGFloat = 8
}
