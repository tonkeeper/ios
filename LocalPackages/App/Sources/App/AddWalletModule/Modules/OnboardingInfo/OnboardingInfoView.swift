import SnapKit
import TKUIKit
import UIKit

final class OnboardingInfoView: UIView, ConfigurableView {
    let scrollView = {
        let view = TKUIScrollView()
        view.alwaysBounceVertical = false
        return view
    }()

    let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        return stackView
    }()

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .Icon.primary
        return imageView
    }()

    let titleDescriptionView: TKTitleDescriptionView = {
        let view = TKTitleDescriptionView(size: .big)
        view.padding = .titleDescriptionPadding
        return view
    }()

    let continueButton = TKButton()
    let continueButtonContainer: TKPaddingContainerView = {
        let container = TKPaddingContainerView()
        container.backgroundView = TKGradientView(color: .Background.page, direction: .bottomToTop)
        container.padding = .continueButtonPadding
        return container
    }()

    struct Model {
        let icon: UIImage?
        let title: String
        let subtitle: String
        let buttonTitle: String
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(model: Model) {
        iconImageView.image = model.icon
        titleDescriptionView.configure(
            model: TKTitleDescriptionView.Model(
                title: model.title,
                bottomDescription: model.subtitle
            )
        )

        var configuration = TKButton.Configuration.actionButtonConfiguration(
            category: .primary,
            size: .large
        )
        configuration.content.title = .plainString(model.buttonTitle)
        continueButton.configuration = configuration
    }
}

private extension OnboardingInfoView {
    func setup() {
        backgroundColor = .Background.page

        addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        addSubview(continueButtonContainer)

        contentStackView.addArrangedSubview(iconImageView)
        contentStackView.addArrangedSubview(titleDescriptionView)

        continueButtonContainer.setViews([continueButton])

        setupConstraints()
    }

    func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
            make.bottom.equalTo(continueButtonContainer.snp.top)
        }

        contentStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-12)
            make.left.right.equalTo(scrollView)
        }

        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(128)
            make.height.equalTo(144)
        }

        titleDescriptionView.snp.makeConstraints { make in
            make.horizontalEdges.equalTo(contentStackView).inset(32)
        }

        continueButtonContainer.snp.makeConstraints { make in
            make.left.right.equalTo(self)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }
    }
}

private extension NSDirectionalEdgeInsets {
    static let titleDescriptionPadding = NSDirectionalEdgeInsets(
        top: 0,
        leading: 0,
        bottom: 16,
        trailing: 0
    )
}

private extension UIEdgeInsets {
    static let continueButtonPadding = UIEdgeInsets(
        top: 16,
        left: 32,
        bottom: 32,
        right: 32
    )
}
