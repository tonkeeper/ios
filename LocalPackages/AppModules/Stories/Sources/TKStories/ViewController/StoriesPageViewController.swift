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
    private var linkRanges: [(range: NSRange, link: StoriesPageModel.Link)] = []

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
        let description = NSMutableAttributedString(
            attributedString: model.description.withTextStyle(.body1, color: .Constant.white, lineBreakMode: .byWordWrapping)
        )
        linkRanges = model.links.compactMap { link in
            let range = (description.string as NSString).range(of: link.text)
            return range.location == NSNotFound ? nil : (range, link)
        }
        for (range, _) in linkRanges {
            description.addAttribute(.foregroundColor, value: UIColor.Accent.blue, range: range)
        }
        descriptionLabel.attributedText = description
        descriptionLabel.accessibilityCustomActions = linkRanges.map { _, link in
            UIAccessibilityCustomAction(name: link.text) { _ in
                link.action()
                return true
            }
        }
        if let button = model.button {
            buttonContainer.isHidden = false
            self.button.configuration.content = TKButton.Configuration.Content(title: .plainString(button.title))
            self.button.configuration.action = button.action
        } else {
            buttonContainer.isHidden = true
        }
    }

    func link(at gesture: UIGestureRecognizer) -> StoriesPageModel.Link? {
        guard !linkRanges.isEmpty, let text = descriptionLabel.attributedText else { return nil }
        let point = gesture.location(in: descriptionLabel)
        let textStorage = NSTextStorage(attributedString: text)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: CGSize(width: descriptionLabel.bounds.width, height: .greatestFiniteMagnitude)
        )
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        return withExtendedLifetime(textStorage) {
            linkRanges.first { range, _ in
                var isHit = false
                layoutManager.enumerateEnclosingRects(
                    forGlyphRange: layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil),
                    withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                    in: textContainer
                ) { rect, stop in
                    isHit = rect.insetBy(dx: -8, dy: -8).contains(point)
                    stop.pointee = ObjCBool(isHit)
                }
                return isHit
            }?.link
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
            make.left.right.equalTo(view)
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }
}
