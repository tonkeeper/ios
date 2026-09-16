import TKUIKit
import UIKit

final class StoriesPageViewController: UIViewController {
    private let stackView = UIStackView()
    private let backgroundImageView = TKImageView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let button = TKButton()
    private let buttonContainer = UIView()
    private var hasAnimatedBackground = false

    private let model: StoriesPageModel

    init(model: StoriesPageModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAnimatedBackground else { return }
        hasAnimatedBackground = true
        UIView.animate(withDuration: 0.3) {
            self.backgroundImageView.alpha = 1
        }
    }

    private func setupContent() {
        backgroundImageView.configure(
            model: TKImageView.Model(
                image: model.backgroundImage,
                tintColor: .clear,
                size: .none,
                corners: .none
            )
        )
        titleLabel.attributedText = model.title.withTextStyle(.h1, color: .Constant.white)
        descriptionLabel.attributedText = model.description.withTextStyle(.body1, color: .Constant.white)
        if let button = model.button {
            buttonContainer.isHidden = false
            self.button.configuration.content = TKButton.Configuration.Content(title: .plainString(button.title))
            self.button.configuration.action = button.action
        } else {
            buttonContainer.isHidden = true
        }
    }

    private func setup() {
        view.backgroundColor = .black

        button.configuration = .actionButtonConfiguration(category: .overlay, size: .medium)
        titleLabel.numberOfLines = 0
        descriptionLabel.numberOfLines = 0

        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.alpha = 0

        stackView.axis = .vertical
        stackView.spacing = 8

        view.addSubview(backgroundImageView)
        view.addSubview(stackView)

        let labelsStackView = UIStackView()
        labelsStackView.axis = .vertical
        labelsStackView.spacing = 8
        labelsStackView.addArrangedSubview(titleLabel)
        labelsStackView.addArrangedSubview(descriptionLabel)

        stackView.addArrangedSubview(labelsStackView)

        let labelsStackViewContainer = UIView()
        labelsStackViewContainer.addSubview(labelsStackView)
        labelsStackView.snp.makeConstraints { make in
            make.edges.equalTo(labelsStackViewContainer).inset(UIEdgeInsets(top: 28, left: 32, bottom: 28, right: 32))
        }
        stackView.addArrangedSubview(labelsStackViewContainer)

        buttonContainer.addSubview(button)
        button.snp.makeConstraints { make in
            make.top.equalTo(buttonContainer)
            make.left.bottom.equalTo(buttonContainer).inset(32)
            make.right.lessThanOrEqualTo(buttonContainer).offset(-32)
        }
        stackView.addArrangedSubview(buttonContainer)

        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
        stackView.snp.makeConstraints { make in
            make.left.bottom.right.equalTo(view)
        }
    }
}
