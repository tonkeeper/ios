import TKUIKit
import UIKit

final class AmountInputConvertedButton: UIControl {
    struct Configuration {
        let text: String
        let symbolConfiguration: AmountInputSymbolView.Configuration
        var showSwitchIcon: Bool
        var showConvertedAmount: Bool
        var isUserInteractionEnabled: Bool
        var showsShimmer: Bool
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
            borderView.alpha = isHighlighted ? 0.48 : 1
        }
    }

    private let label = UILabel()
    private let symbolView = AmountInputSymbolView()
    private let swapImageView = AmountInputConvertedSwapImageView()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 4
        stackView.axis = .horizontal
        return stackView
    }()

    private let borderView = UIView()
    private let shimmerView = TKShimmerView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        borderView.layer.cornerRadius = bounds.height / 2
    }

    private func setup() {
        borderView.isUserInteractionEnabled = false

        borderView.layer.borderWidth = 1.5
        borderView.layer.borderColor = UIColor.Button.tertiaryBackground.cgColor
        borderView.layer.cornerCurve = .continuous

        addSubview(borderView)
        borderView.addSubview(stackView)
        borderView.addSubview(shimmerView)

        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(symbolView)
        stackView.addArrangedSubview(swapImageView)

        setupConstraints()
    }

    private func setupConstraints() {
        borderView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(borderView).inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        }
        shimmerView.snp.makeConstraints { make in
            make.edges.equalTo(borderView)
        }
    }

    private func didUpdateConfiguration() {
        guard let configuration else {
            label.text = nil
            symbolView.configuration = nil
            swapImageView.isHidden = false
            stackView.isHidden = false
            shimmerView.isHidden = true
            shimmerView.stopAnimation()
            isUserInteractionEnabled = true
            return
        }

        if configuration.showsShimmer {
            stackView.isHidden = true
            shimmerView.isHidden = false
            shimmerView.startAnimation()
            isUserInteractionEnabled = false
            return
        }

        stackView.isHidden = false
        shimmerView.isHidden = true
        shimmerView.stopAnimation()

        if configuration.showConvertedAmount {
            label.attributedText = configuration.text.withTextStyle(
                .body1,
                color: .Text.secondary
            )
            label.isHidden = false
        } else {
            label.attributedText = nil
            label.isHidden = true
        }
        symbolView.configuration = configuration.symbolConfiguration
        swapImageView.isHidden = !configuration.showSwitchIcon
        isUserInteractionEnabled = configuration.isUserInteractionEnabled
    }
}

private final class AmountInputConvertedSwapImageView: UIView {
    private let imageView = TKImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        addSubview(imageView)

        imageView.configure(
            model: TKImageView.Model(
                image: .image(.TKUIKit.Icons.Size16.swapVertical),
                tintColor: .Icon.secondary,
                size: .size(CGSize(width: 16, height: 16))
            )
        )

        imageView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 0))
        }
    }
}
