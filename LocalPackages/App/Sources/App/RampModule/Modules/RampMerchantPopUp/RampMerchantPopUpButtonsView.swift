import SnapKit
import TKUIKit
import UIKit

final class RampMerchantPopUpButtonsView: UIView {
    private let textView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = true
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

    private var onLinkTap: ((URL) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct ButtonItem {
        let title: String
        let url: URL?
    }

    func configure(buttons: [ButtonItem], onLinkTap: @escaping (URL) -> Void) {
        self.onLinkTap = onLinkTap

        guard !buttons.isEmpty else {
            textView.attributedText = nil
            return
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let separator = " · "
        let fullText = buttons.map(\.title).joined(separator: separator)
        let attributed = NSMutableAttributedString(string: fullText, attributes: [
            .foregroundColor: UIColor.Text.secondary,
            .font: TKTextStyle.body1.font,
            .paragraphStyle: paragraphStyle,
        ])

        var location = 0
        for (index, button) in buttons.enumerated() {
            let length = (button.title as NSString).length
            let range = NSRange(location: location, length: length)
            if let url = button.url {
                attributed.addAttribute(.link, value: url, range: range)
            }
            location += length
            if index < buttons.count - 1 {
                location += (separator as NSString).length
            }
        }

        textView.attributedText = attributed
        textView.delegate = self
    }
}

extension RampMerchantPopUpButtonsView: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        onLinkTap?(url)
        return false
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        textView.selectedTextRange = nil
    }
}

private extension RampMerchantPopUpButtonsView {
    func setup() {
        addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(32)
        }
    }
}
