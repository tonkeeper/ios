import TKLocalize
import TKUIKit
import UIKit

final class SendAssetExchangeView: UIView {
    struct Model: Equatable {
        enum RateValue: Equatable {
            case empty
            case shimmer
            case text(String)
        }

        let fromImageUrl: URL?
        let fromCode: String
        let fromNetwork: String
        let toCode: String
        let toNetwork: String
        let toImageUrl: URL?
        let rate: RateValue
        let subtitle: String?
    }

    private let fromImageView = TKOutsideBorderImageView()
    private let toImageView = TKOutsideBorderImageView()
    private let textStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        return stack
    }()

    private let subtitleLabel = UILabel()
    private let sendLabel = UILabel()
    private let receiveLabel = UILabel()
    private let rateLabel = UILabel()
    private let rateShimmerView = TKShimmerView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        sendLabel.font = TKTextStyle.h1.font
        sendLabel.textColor = .Text.primary
        receiveLabel.font = TKTextStyle.h1.font
        receiveLabel.textColor = .Text.primary
        rateLabel.font = TKTextStyle.body1.font
        rateLabel.textColor = .Text.secondary

        subtitleLabel.font = TKTextStyle.body1.font
        subtitleLabel.textColor = .Text.secondary

        textStackView.addArrangedSubview(subtitleLabel)
        textStackView.addArrangedSubview(sendLabel)
        textStackView.addArrangedSubview(receiveLabel)
        textStackView.addArrangedSubview(rateLabel)
        textStackView.addArrangedSubview(rateShimmerView)
        textStackView.setCustomSpacing(Constants.rateLabelTopOffset, after: receiveLabel)

        addSubview(fromImageView)
        addSubview(toImageView)
        addSubview(textStackView)

        setupConstraints()
    }

    private func setupConstraints() {
        fromImageView.snp.makeConstraints { make in
            make.top.equalTo(self)
            make.centerX.equalTo(self).offset(-Constants.imageCenterOffset)
            make.size.equalTo(Constants.imageSize)
        }
        toImageView.snp.makeConstraints { make in
            make.top.equalTo(self)
            make.centerX.equalTo(self).offset(Constants.imageCenterOffset)
            make.size.equalTo(Constants.imageSize)
        }
        textStackView.snp.makeConstraints { make in
            make.top.equalTo(fromImageView.snp.bottom).offset(Constants.sendLabelTopOffset)
            make.leading.trailing.equalTo(self)
            make.bottom.equalTo(self)
        }
        rateShimmerView.snp.makeConstraints { make in
            make.width.equalTo(Constants.rateShimmerWidth)
            make.height.equalTo(Constants.rateShimmerHeight)
        }
    }

    func configure(model: Model) {
        let hasSubtitle = model.subtitle != nil
        subtitleLabel.isHidden = !hasSubtitle
        subtitleLabel.text = model.subtitle
        if hasSubtitle {
            textStackView.setCustomSpacing(Constants.subtitleToSendSpacing, after: subtitleLabel)
        }

        sendLabel.attributedText = attributeText(prefix: TKLocales.NativeSwap.Field.send, code: model.fromCode, network: model.fromNetwork)
        receiveLabel.attributedText = attributeText(prefix: TKLocales.NativeSwap.Field.receive, code: model.toCode, network: model.toNetwork)

        switch model.rate {
        case .empty:
            rateLabel.isHidden = true
            rateLabel.attributedText = nil
            rateShimmerView.isHidden = true
            rateShimmerView.stopAnimation()
        case .shimmer:
            rateLabel.isHidden = true
            rateLabel.attributedText = nil
            rateShimmerView.isHidden = false
            rateShimmerView.startAnimation()
        case let .text(rateText):
            rateLabel.isHidden = false
            rateLabel.attributedText = rateText.withTextStyle(.body1, color: .Text.secondary)
            rateShimmerView.isHidden = true
            rateShimmerView.stopAnimation()
        }

        let fromConfig = TKOutsideBorderImageView.Configuration(
            image: .urlImage(model.fromImageUrl),
            imageSize: CGSize(width: Constants.configurationImageSize, height: Constants.configurationImageSize),
            borderWidth: Constants.borderWidth,
            borderColor: .Background.page
        )
        let toConfig = TKOutsideBorderImageView.Configuration(
            image: .urlImage(model.toImageUrl),
            imageSize: CGSize(width: Constants.configurationImageSize, height: Constants.configurationImageSize),
            borderWidth: Constants.borderWidth,
            borderColor: .Background.page
        )
        fromImageView.configuration = fromConfig
        toImageView.configuration = toConfig
    }

    private func attributeText(prefix: String, code: String, network: String) -> NSAttributedString {
        let resultString = prefix + " " + code + " " + network
        let attributed = NSMutableAttributedString(
            string: resultString,
            attributes: [
                .foregroundColor: UIColor.Text.primary,
                .font: TKTextStyle.h2.font,
            ]
        )

        let rangeToColor: Range<String.Index>?
        if code == network,
           let firstRange = resultString.range(of: network),
           let secondRange = resultString.range(of: network, range: firstRange.upperBound ..< resultString.endIndex)
        {
            rangeToColor = secondRange
        } else {
            rangeToColor = resultString.range(of: network)
        }
        if let range = rangeToColor {
            let nsRange = NSRange(range, in: resultString)
            attributed.addAttribute(.foregroundColor, value: UIColor.Text.tertiary, range: nsRange)
        }

        return attributed
    }
}

private extension SendAssetExchangeView {
    enum Constants {
        static let imageSize: CGFloat = 80
        static let imageSpacing: CGFloat = -16
        static var imageCenterOffset: CGFloat {
            (imageSize + imageSpacing) / 2
        }

        static let sendLabelTopOffset: CGFloat = 16
        static let subtitleToSendSpacing: CGFloat = 8
        static let rateLabelTopOffset: CGFloat = 4
        static let rateShimmerWidth: CGFloat = 136
        static let rateShimmerHeight: CGFloat = 24
        static let configurationImageSize: CGFloat = 72
        static let borderWidth: CGFloat = 4
    }
}
