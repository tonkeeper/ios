import SnapKit
import TKUIKit
import UIKit

final class NFTDetailsMoreTextView: TKView, ConfigurableView {
    var didExpand: (() -> Void)?

    var numberOfLinesCollapsed = 2
    private var isExpanded = false {
        didSet {
            invalidateIntrinsicContentSize()
            moreButton.isHidden = isExpanded
            didExpand?()
        }
    }

    let label = UILabel()
    private let moreButton = TKMoreButton()

    private var cachedWidth: CGFloat?

    override func setup() {
        super.setup()
        layer.masksToBounds = true

        label.numberOfLines = 0

        addSubview(label)
        addSubview(moreButton)

        moreButton.addAction(UIAction(handler: { [weak self] _ in
            self?.isExpanded = true
        }), for: .touchUpInside)

        setupConstraints()
    }

    func setupConstraints() {
        label.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
        }

        moreButton.snp.makeConstraints { make in
            make.right.bottom.equalTo(self)
        }
    }

    struct Model {
        let text: NSAttributedString?
        let readMoreText: String?

        init(text: String?, readMoreText: String) {
            self.text = text?.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            )
            self.readMoreText = readMoreText
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width != cachedWidth {
            cachedWidth = bounds.width
            invalidateIntrinsicContentSize()
        }

        configureMoreButtonVisibility()
    }

    func configure(model: Model) {
        label.attributedText = model.text
        moreButton.configuration = .init(title: model.readMoreText)
        cachedWidth = nil

        setNeedsLayout()
    }

    private func configureMoreButtonVisibility() {
        let textViewSizeThatFits = label.heightThatFits(.greatestFiniteMagnitude)
        let maximumHeight = TKTextStyle.body2.lineHeight * CGFloat(numberOfLinesCollapsed)
        moreButton.isHidden = (isExpanded || !(textViewSizeThatFits > maximumHeight))
    }

    override var intrinsicContentSize: CGSize {
        let textViewSizeThatFits = label.sizeThatFits(CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude))
        guard !isExpanded else {
            return CGSize(width: UIView.noIntrinsicMetric, height: textViewSizeThatFits.height)
        }

        let maximumHeight = TKTextStyle.body2.lineHeight * CGFloat(numberOfLinesCollapsed)
        return CGSize(width: UIView.noIntrinsicMetric, height: min(maximumHeight, textViewSizeThatFits.height))
    }
}
