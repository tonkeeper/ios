import SnapKit
import TKUIKit
import UIKit

final class RampWarningView: UIView {
    private let containerView = UIView()
    private let label = UILabel()
    private let iconImageView = TKImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(attributedText: NSAttributedString?) {
        label.attributedText = attributedText
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let contentWidth = size.width - Constants.Label.leading - Constants.Image.trailing
        let labelSize = label.sizeThatFits(CGSize(
            width: contentWidth - Constants.Label.trailing - Constants.Image.size.width,
            height: .greatestFiniteMagnitude
        ))

        let height: CGFloat = max(labelSize.height, Constants.Image.size.height)
            + (Constants.Label.vertical * 2)

        return CGSize(width: size.width, height: height)
    }
}

private extension RampWarningView {
    func setup() {
        iconImageView.configure(model: TKImageView.Model(
            image: .image(.TKUIKit.Icons.Size16.exclamationmarkTriangle),
            tintColor: .Icon.secondary,
            size: .size(Constants.Image.size)
        ))

        label.numberOfLines = 0

        containerView.backgroundColor = .Background.content
        containerView.layer.cornerRadius = Constants.cornerRadius
        containerView.layer.masksToBounds = true

        addSubview(containerView)
        containerView.addSubviews(label, iconImageView)

        setupConstraints()
    }

    func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        iconImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.Image.size)
            make.top.equalToSuperview().inset(Constants.Image.top)
            make.trailing.equalToSuperview().inset(Constants.Image.trailing)
        }

        label.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Constants.Label.vertical)
            make.leading.equalToSuperview().inset(Constants.Label.leading)
            make.trailing.equalTo(iconImageView.snp.leading).inset(-Constants.Label.trailing)
        }
    }

    enum Constants {
        enum Image {
            static let size = CGSize(width: 16, height: 16)
            static let top: CGFloat = 16
            static let trailing: CGFloat = 16
        }

        enum Label {
            static let vertical: CGFloat = 12
            static let leading: CGFloat = 16
            static let trailing: CGFloat = 12
        }

        static let cornerRadius: CGFloat = 16
    }
}
