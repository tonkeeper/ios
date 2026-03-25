import TKUIKit
import UIKit

final class BrowserAppCollectionViewCell: UICollectionViewCell, ReusableView {
    var didLongPress: (() -> Void)?

    let iconImageView = TKImageView()
    let titleLabel = UILabel()

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.48 : 1
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.prepareForReuse()
    }

    struct Configuration: Hashable {
        let id: String
        let title: NSAttributedString
        let isTwoLinesTitle: Bool
        let iconModel: TKImageView.Model

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: Configuration, rhs: Configuration) -> Bool {
            return lhs.id == rhs.id
        }

        init(
            id: String,
            title: String,
            isTwoLinesTitle: Bool,
            iconModel: TKImageView.Model
        ) {
            self.id = id
            self.title = title.withTextStyle(
                .body3,
                color: .Text.secondary,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            self.isTwoLinesTitle = isTwoLinesTitle
            self.iconModel = iconModel
        }
    }

    func configure(configuration: Configuration) {
        titleLabel.attributedText = configuration.title
        titleLabel.numberOfLines = configuration.isTwoLinesTitle ? 2 : 1
        iconImageView.configure(model: configuration.iconModel)
        setNeedsLayout()
    }
}

private extension BrowserAppCollectionViewCell {
    func setup() {
        addSubview(titleLabel)
        addSubview(iconImageView)

        iconImageView.snp.makeConstraints { make in
            make.top.equalTo(self).offset(8)
            make.centerX.equalTo(self)
            make.size.equalTo(64)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(8)
            make.left.right.equalTo(self)
            make.bottom.equalTo(self).offset(-8)
        }

        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressGestureHandler(recognizer:)))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)
    }

    @objc
    func longPressGestureHandler(recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            didLongPress?()
        default:
            break
        }
    }
}
