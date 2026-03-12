import TKLocalize
import TKUIKit
import UIKit

final class OnboardingRootView: UIView, ConfigurableView {
    let titleDescriptionView: TKTitleDescriptionView = {
        let view = TKTitleDescriptionView(size: .big)
        view.padding.bottom = .titleBottomPadding
        view.padding.leading = 32
        view.padding.trailing = 32
        return view
    }()

    let bottomControlsContainer: TKPaddingContainerView = {
        let view = TKPaddingContainerView()
        view.padding = .controlsContainerPadding
        view.spacing = TKPaddingContainerView.buttonsContainerSpacing
        return view
    }()

    let createButton = TKButton()
    let importButton = TKButton()
    let termsTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textAlignment = .center
        textView.textContainerInset = UIEdgeInsets(top: .extraTermsTextTopInset, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.Text.accent,
        ]
        return textView
    }()

    let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = .Onboarding.cover
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        let titleDescriptionModel: TKTitleDescriptionView.Model
        let createButtonConfiguration: TKButton.Configuration
        let importButtonConfiguration: TKButton.Configuration
    }

    func configure(model: Model) {
        titleDescriptionView.configure(model: model.titleDescriptionModel)
        createButton.configuration = model.createButtonConfiguration
        importButton.configuration = model.importButtonConfiguration
        configureTermsText()
    }
}

private extension OnboardingRootView {
    func setup() {
        backgroundColor = .Background.page

        bottomControlsContainer.setViews([createButton, importButton, termsTextView])

        addSubview(coverImageView)
        addSubview(titleDescriptionView)
        addSubview(bottomControlsContainer)

        setupConstraints()
    }

    func setupConstraints() {
        titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false
        bottomControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        coverImageView.translatesAutoresizingMaskIntoConstraints = false

        coverImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        NSLayoutConstraint.activate([
            bottomControlsContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomControlsContainer.leftAnchor.constraint(equalTo: leftAnchor),
            bottomControlsContainer.rightAnchor.constraint(equalTo: rightAnchor),

            titleDescriptionView.bottomAnchor.constraint(equalTo: bottomControlsContainer.topAnchor),
            titleDescriptionView.leftAnchor.constraint(equalTo: leftAnchor),
            titleDescriptionView.rightAnchor.constraint(equalTo: rightAnchor),

            coverImageView.bottomAnchor.constraint(equalTo: titleDescriptionView.topAnchor, constant: -24),
            coverImageView.leftAnchor.constraint(equalTo: titleDescriptionView.leftAnchor),
            coverImageView.rightAnchor.constraint(equalTo: titleDescriptionView.rightAnchor),
            coverImageView.topAnchor.constraint(equalTo: topAnchor),
        ])
    }

    func configureTermsText() {
        let caption = TKLocales.Onboarding.Terms.caption(TKLocales.Onboarding.Terms.title)
        let textStyle = TKTextStyle.body2
        let attributedText = NSMutableAttributedString(
            string: caption,
            attributes: textStyle.getAttributes(
                color: .Text.secondary,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
        )
        let linkRange = (caption as NSString).range(of: TKLocales.Onboarding.Terms.title)
        if let url = URL(string: "https://tonkeeper.com/terms") {
            attributedText.addAttribute(.link, value: url, range: linkRange)
        }
        termsTextView.attributedText = attributedText
    }
}

private extension CGFloat {
    static let titleBottomPadding: CGFloat = 32
    static let extraTermsTextTopInset: CGFloat = 14
    static let buttonsContainerSpacing: CGFloat = 16
}

private extension UIEdgeInsets {
    static var controlsContainerPadding: UIEdgeInsets {
        UIEdgeInsets(top: 16, left: 32, bottom: 18, right: 32)
    }
}
