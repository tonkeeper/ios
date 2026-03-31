import SnapKit
import TKUIKit
import UIKit

final class CurrencyPickerButton: UIControl {
    var didTap: (() -> Void)?

    struct Configuration {
        let currencyCode: String?
        let image: TKImage?
    }

    var configuration: Configuration? {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.48 : 1
        }
    }

    private let imageView = TKImageView()
    private let codeLabel = UILabel()
    private let switchImageView = TKImageView()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.spacing = 4
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        addSubview(stackView)

        codeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        codeLabel.textColor = .Text.primary
        codeLabel.font = TKTextStyle.body2.font
        codeLabel.isUserInteractionEnabled = false

        switchImageView.configure(model: TKImageView.Model(image: .image(.TKUIKit.Icons.Size16.switch)))
        switchImageView.tintColor = .Icon.tertiary
        switchImageView.isUserInteractionEnabled = false

        stackView.isUserInteractionEnabled = false

        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(codeLabel)
        stackView.addArrangedSubview(switchImageView)

        addAction(UIAction(handler: { [weak self] _ in
            self?.didTap?()
        }), for: .touchUpInside)

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        imageView.snp.makeConstraints { make in
            make.width.size.equalTo(Constants.imageSize)
        }

        switchImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.switchSize)
        }
    }

    private func didUpdateConfiguration() {
        guard let configuration else {
            imageView.configure(model: TKImageView.Model(image: nil))
            codeLabel.text = nil
            return
        }

        codeLabel.text = configuration.currencyCode

        let image = configuration.image ?? .image(.TKUIKit.Icons.Size16.globe)
        imageView.configure(
            model: TKImageView.Model(
                image: image,
                size: .size(Constants.imageSize),
                corners: .circle
            )
        )
    }
}

private extension CurrencyPickerButton {
    enum Constants {
        static let switchSize = CGSize(width: 16, height: 16)
        static let imageSize = CGSize(width: 16, height: 16)
    }
}
