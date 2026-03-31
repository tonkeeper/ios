import TKLocalize
import TKUIKit
import UIKit

final class SendAssetDisclaimerView: UIView {
    struct Model {
        let text: String
        let linkText: String
        let linkURL: URL?

        static let changelly = Model(
            text: TKLocales.Ramp.Deposit.changellyDisclaimer,
            linkText: TKLocales.Ramp.Deposit.changellyTermsOfUse,
            linkURL: URL(string: "https://changelly.com/terms-of-use")
        )
    }

    private let textView: UITextView = {
        let textView = UITextView()

        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = true
        textView.dataDetectorTypes = .link

        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.Accent.blue,
        ]

        if #available(iOS 18.0, *) {
            textView.writingToolsBehavior = .none
        }

        return textView
    }()

    private var verticalInsets: Bool

    init(verticalInsets: Bool) {
        self.verticalInsets = verticalInsets

        super.init(frame: .zero)
        setup()
    }

    private func setup() {
        textView.delegate = self
        addSubview(textView)

        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
                .inset(
                    UIEdgeInsets(
                        top: verticalInsets ? 12 : 0,
                        left: 16,
                        bottom: verticalInsets ? 16 : 0,
                        right: 16
                    )
                )
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(model: Model) {
        let attributed = NSMutableAttributedString(string: model.text, attributes: [
            .foregroundColor: UIColor.Text.secondary,
            .font: TKTextStyle.body2.font,
        ])

        if let range = model.text.range(of: model.linkText), let url = model.linkURL {
            attributed.addAttribute(.link, value: url, range: NSRange(range, in: model.text))
        }

        textView.attributedText = attributed
    }
}

extension SendAssetDisclaimerView: UITextViewDelegate {
    func textViewDidChangeSelection(_ textView: UITextView) {
        textView.selectedTextRange = nil
    }
}
