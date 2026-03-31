import TKUIKit
import UIKit

struct HistoryEventDetailsSpamManagementComponent: TKPopUp.Item {
    func getView() -> UIView {
        return HistoryEventDetailsSpamManagementComponentView(
            configuration: configuration
        )
    }

    private let configuration: HistoryEventDetailsSpamManagementComponentView.Configuration
    let bottomSpace: CGFloat

    init(
        configuration: HistoryEventDetailsSpamManagementComponentView.Configuration,
        bottomSpace: CGFloat
    ) {
        self.configuration = configuration
        self.bottomSpace = bottomSpace
    }
}

final class HistoryEventDetailsSpamManagementComponentView: UIView {
    struct Configuration {
        let reportSpamTitle: String
        let reportSpamAction: () -> Void
        let notSpamTitle: String
        let notSpamAction: () -> Void
    }

    private let reportSpamButton = TKButton()
    private let notSpamButton = TKButton()
    private let stackView = UIStackView()

    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        setupButtons()
        stackView.axis = .horizontal
        stackView.spacing = 8

        addSubview(stackView)
        stackView.addArrangedSubview(reportSpamButton)
        stackView.addArrangedSubview(notSpamButton)

        stackView.snp.makeConstraints { make in
            make.top.bottom.equalTo(self)
            make.centerX.equalTo(self)
            make.left.greaterThanOrEqualTo(self).priority(.medium)
            make.right.lessThanOrEqualTo(self).priority(.medium)
        }
    }

    private func setupButtons() {
        var reportSpamButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: .primary,
            size: .small
        )
        reportSpamButtonConfiguration.content = .init(title: .plainString(configuration.reportSpamTitle))
        reportSpamButtonConfiguration.backgroundColors = [
            .normal: .Accent.orange,
            .highlighted: .Accent.orange.withAlphaComponent(0.64),
        ]
        reportSpamButtonConfiguration.action = { [weak self] in
            self?.configuration.reportSpamAction()
        }
        reportSpamButton.configuration = reportSpamButtonConfiguration

        var notSpamButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: .secondary,
            size: .small
        )
        notSpamButtonConfiguration.content = .init(title: .plainString(configuration.notSpamTitle))
        notSpamButtonConfiguration.action = { [weak self] in
            self?.configuration.notSpamAction()
        }
        notSpamButton.configuration = notSpamButtonConfiguration
    }
}
