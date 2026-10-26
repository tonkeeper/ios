import UIKit

public final class InfoPopupBottomSheetViewController: UIViewController, TKBottomSheetScrollContentViewController {
    public struct Configuration {
        public enum BodyView {
            case textWithTabs(content: [String])
        }

        public let image: UIImage?
        public let imageTintColor: UIColor?
        public let title: String
        public let caption: String
        public let footnote: String?
        public let bodyContent: [BodyView]?
        public let buttons: [TKButton.Configuration]

        public init(
            image: UIImage?,
            imageTintColor: UIColor?,
            title: String,
            caption: String,
            footnote: String? = nil,
            bodyContent: [BodyView]?,
            buttons: [TKButton.Configuration]
        ) {
            self.image = image
            self.imageTintColor = imageTintColor
            self.title = title
            self.caption = caption
            self.footnote = footnote
            self.bodyContent = bodyContent
            self.buttons = buttons
        }
    }

    public var didUpdateHeight: (() -> Void)?

    public var headerConfiguration: TKBottomSheetHeaderConfiguration?
    public var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)?
    public func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        stackView.systemLayoutSizeFitting(
            CGSize(width: width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }

    public let scrollView = UIScrollView()

    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let captionLabel = UILabel()
    private let footnoteLabel = UILabel()
    private let titleCaptionStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        return stackView
    }()

    private let titleCaptionPaddingView = UIView()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        return stackView
    }()

    private let buttonsPaddingContainer: TKPaddingContainerView = {
        let container = TKPaddingContainerView()
        container.padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return container
    }()

    public var configuration: Configuration? {
        didSet {
            updateConfiguration()
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }

    private func setup() {
        titleLabel.numberOfLines = 0
        captionLabel.numberOfLines = 0
        footnoteLabel.numberOfLines = 0

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        titleCaptionPaddingView.addSubview(titleCaptionStackView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(self.view)
        }
        stackView.snp.makeConstraints { make in
            make.edges.width.equalTo(scrollView)
        }
        titleCaptionStackView.snp.makeConstraints { make in
            make.top.equalTo(titleCaptionPaddingView)
            make.left.right.equalTo(titleCaptionPaddingView).inset(32)
            make.bottom.equalTo(titleCaptionPaddingView).inset(16)
        }
        buttonsPaddingContainer.snp.makeConstraints { make in
            make.width.equalTo(stackView)
        }
    }

    private func updateConfiguration() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stackView.addArrangedSubview(imageView)
        stackView.setCustomSpacing(12, after: imageView)
        stackView.addArrangedSubview(titleCaptionPaddingView)

        titleCaptionStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        titleCaptionStackView.addArrangedSubview(titleLabel)
        titleCaptionStackView.addArrangedSubview(captionLabel)
        if let footnote = configuration?.footnote {
            titleCaptionStackView.addArrangedSubview(footnoteLabel)
            titleCaptionStackView.setCustomSpacing(12, after: captionLabel)
            footnoteLabel.attributedText = footnote.withTextStyle(.body2, color: .Text.tertiary, alignment: .center)
        }

        imageView.isHidden = configuration?.image == nil
        imageView.image = configuration?.image
        imageView.tintColor = configuration?.imageTintColor

        titleLabel.attributedText = configuration?.title.withTextStyle(.h2, color: .Text.primary, alignment: .center)
        captionLabel.attributedText = configuration?.caption.withTextStyle(.body1, color: .Text.secondary, alignment: .center)

        updateBodyConfiguration()

        stackView.addArrangedSubview(buttonsPaddingContainer)
        let buttons = (configuration?.buttons ?? []).map { configuration in
            let button = TKButton()
            button.configuration = configuration
            return button
        }
        buttonsPaddingContainer.setViews(buttons)
    }

    private func updateBodyConfiguration() {
        guard let bodyContent = configuration?.bodyContent, !bodyContent.isEmpty else {
            return
        }

        for item in bodyContent {
            let containerView = TKPaddingContainerView()
            containerView.padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            stackView.addArrangedSubview(containerView)

            containerView.snp.makeConstraints { $0.width.equalTo(stackView) }

            switch item {
            case let .textWithTabs(content):
                let tabView = TabLabelView()
                tabView.configure(model: .init(content: content))
                containerView.setViews([tabView])

                tabView.snp.makeConstraints { $0.edges.equalToSuperview() }
            }
        }
    }
}
