import SnapKit
import TKUIKit
import UIKit

final class PaymentMethodStablecoinContentView: UIView {
    struct Configuration: Hashable {
        let image: TKImage?
        let title: String
        let networkIconURLs: [URL]
    }

    var configuration = Configuration(image: nil, title: "", networkIconURLs: []) {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private let imageView = TKImageView()
    private let titleLabel = UILabel()
    private let overlappingIconsView = OverlappingIconsView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard size.width > 0 else { return .zero }
        return CGSize(width: size.width, height: Constants.contentHeight)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Constants.contentHeight)
    }

    func prepareForReuse() {
        overlappingIconsView.prepareForReuse()
    }

    private func setup() {
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(overlappingIconsView)

        imageView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(imageView.snp.trailing).offset(Constants.textLeftPadding)
            make.centerY.equalToSuperview()
            make.trailing.equalTo(overlappingIconsView.snp.leading).offset(-Constants.spacingBetweenTextAndIcons)
        }

        overlappingIconsView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.equalTo(titleLabel.snp.trailing).offset(Constants.spacingBetweenTextAndIcons)
        }

        didUpdateConfiguration()
    }

    private func didUpdateConfiguration() {
        imageView.configure(model: TKImageView.Model(
            image: configuration.image ?? .image(nil),
            size: .size(Constants.iconSize),
            corners: .circle
        ))
        titleLabel.attributedText = configuration.title.withTextStyle(
            .label1,
            color: .Text.primary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        overlappingIconsView.configure(model: .init(iconURLs: configuration.networkIconURLs))
        overlappingIconsView.isHidden = configuration.networkIconURLs.isEmpty
    }
}

private extension PaymentMethodStablecoinContentView {
    enum Constants {
        static let iconSize = CGSize(width: 28, height: 28)
        static let textLeftPadding: CGFloat = 16
        static let spacingBetweenTextAndIcons: CGFloat = 6
        static let contentHeight: CGFloat = 28
    }
}
