import SnapKit
import TKUIKit
import UIKit

final class SendAssetWarningView: UIView {
    struct Model {
        let text: String
        let highlightedText: String
    }

    private let contentView = RampWarningView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    private func setup() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(model: Model) {
        let attributed = NSMutableAttributedString(string: model.text, attributes: [
            .foregroundColor: UIColor.Text.primary,
            .font: TKTextStyle.body2.font,
        ])

        if let range = model.text.range(of: model.highlightedText) {
            let nsRange = NSRange(range, in: model.text)
            attributed.addAttribute(.foregroundColor, value: UIColor.Accent.orange, range: nsRange)
        }

        contentView.configure(attributedText: attributed)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        contentView.sizeThatFits(size)
    }
}
