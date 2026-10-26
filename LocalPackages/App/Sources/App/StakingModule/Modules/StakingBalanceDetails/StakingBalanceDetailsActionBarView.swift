import TKUIKit
import UIKit

final class StakingBalanceDetailsActionBarView: UIView, ConfigurableView {
    struct Model {
        struct Button {
            let title: String
            let isEnabled: Bool
            let action: () -> Void
            let accessibilityIdentifier: String?
        }

        let buttons: [Button]
    }

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(self).offset(16)
            make.left.right.equalTo(self).inset(16)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(3)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(model: Model) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for item in model.buttons {
            var configuration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
            configuration.content = TKButton.Configuration.Content(title: .plainString(item.title))
            configuration.isEnabled = item.isEnabled
            configuration.action = item.action
            let button = TKButton(configuration: configuration)
            button.accessibilityIdentifier = item.accessibilityIdentifier
            stackView.addArrangedSubview(button)
        }
    }
}
