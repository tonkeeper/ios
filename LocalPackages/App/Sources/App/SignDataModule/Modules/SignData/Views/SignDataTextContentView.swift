import TKUIKit
import UIKit

public final class SignDataTextContentView: UIView, TKPopUp.Item {
    public struct Model {
        public let text: String
        public let caption: String
        public let copyButtonContent: TKButton.Configuration.Content
        public let copyButtonAction: () -> Void
    }

    public var bottomSpace: CGFloat = 0

    public func getView() -> UIView {
        return self
    }

    let copyButton = TKButton(configuration: .actionButtonConfiguration(category: .tertiary, size: .small))

    private let textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    private let captionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        return stackView
    }()

    private let textContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .Background.content
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    init(with model: Model) {
        super.init(frame: .zero)
        setup(with: model)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(with model: Model) {
        copyButton.configuration.content = model.copyButtonContent
        copyButton.configuration.action = model.copyButtonAction

        textLabel.attributedText = model.text.withTextStyle(.body1Mono, color: .Text.primary)
        captionLabel.attributedText = model.caption.withTextStyle(.body2, color: .Text.secondary)

        stackView.addArrangedSubview(textContainerView)
        stackView.addArrangedSubview(captionLabel)

        textContainerView.addSubview(textLabel)
        textContainerView.addSubview(copyButton)

        addSubview(stackView)

        setupConstraints()
    }

    private func setupConstraints() {
        textLabel.snp.makeConstraints { make in
            make.top.equalTo(textContainerView).offset(12)
            make.leading.equalTo(textContainerView).offset(16)
            make.trailing.equalTo(textContainerView).offset(-16)
            make.bottom.lessThanOrEqualTo(textContainerView).offset(-12)
        }

        textContainerView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(120)
            make.top.equalTo(stackView)
            make.leading.equalTo(stackView)
            make.trailing.equalTo(stackView)
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        copyButton.snp.makeConstraints { make in
            make.bottom.equalTo(textContainerView).offset(-16)
            make.trailing.equalTo(textContainerView).offset(-16)
        }
    }
}
