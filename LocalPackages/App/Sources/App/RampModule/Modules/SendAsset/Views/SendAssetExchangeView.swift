import TKLocalize
import TKUIKit
import UIKit

final class SendAssetExchangeView: UIView {
    struct Model: Equatable {
        let fromImageUrl: URL?
        let fromCode: String
        let fromNetwork: String
        let toCode: String
        let toNetwork: String
        let toImageUrl: URL?
        let rateText: String?
    }

    private let fromImageView = TKOutsideBorderImageView()
    private let toImageView = TKOutsideBorderImageView()
    private let fromImageViewOverlay = TKOutsideBorderImageView()
    private let toImageViewOverlay = TKOutsideBorderImageView()
    private let sendLabel = UILabel()
    private let receiveLabel = UILabel()
    private let rateLabel = UILabel()
    private let rateShimmerView = TKShimmerView()

    private var isSwapAnimationRunning = false

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

        fromImageViewOverlay.alpha = 0
        toImageViewOverlay.alpha = 0

        addSubview(fromImageView)
        addSubview(toImageView)
        addSubview(toImageViewOverlay)
        addSubview(fromImageViewOverlay)
        addSubview(sendLabel)
        addSubview(receiveLabel)
        addSubview(rateLabel)
        addSubview(rateShimmerView)

        setupConstraints()
    }

    private func setupConstraints() {
        for item in [fromImageView, fromImageViewOverlay] {
            item.snp.makeConstraints { make in
                make.top.equalTo(self)
                make.centerX.equalTo(self).offset(-Constants.imageCenterOffset)
                make.size.equalTo(Constants.imageSize)
            }
        }
        for item in [toImageView, toImageViewOverlay] {
            item.snp.makeConstraints { make in
                make.top.equalTo(self)
                make.centerX.equalTo(self).offset(Constants.imageCenterOffset)
                make.size.equalTo(Constants.imageSize)
            }
        }
        sendLabel.snp.makeConstraints { make in
            make.top.equalTo(fromImageView.snp.bottom).offset(Constants.sendLabelTopOffset)
            make.centerX.equalTo(self)
        }
        receiveLabel.snp.makeConstraints { make in
            make.top.equalTo(sendLabel.snp.bottom).offset(Constants.receiveLabelTopOffset)
            make.centerX.equalTo(self)
        }
        rateLabel.snp.makeConstraints { make in
            make.top.equalTo(receiveLabel.snp.bottom).offset(Constants.rateLabelTopOffset)
            make.centerX.equalTo(self)
            make.bottom.equalTo(self)
        }
        rateShimmerView.snp.makeConstraints { make in
            make.top.equalTo(receiveLabel.snp.bottom).offset(Constants.rateLabelTopOffset)
            make.centerX.equalTo(self)
            make.width.equalTo(Constants.rateShimmerWidth)
            make.height.equalTo(Constants.rateShimmerHeight)
            make.bottom.equalTo(self)
        }
    }

    func configure(model: Model) {
        sendLabel.attributedText = attributeText(prefix: TKLocales.NativeSwap.Field.send, code: model.fromCode, network: model.fromNetwork)
        receiveLabel.attributedText = attributeText(prefix: TKLocales.NativeSwap.Field.receive, code: model.toCode, network: model.toNetwork)

        let hasRate = model.rateText != nil
        rateLabel.isHidden = !hasRate
        rateLabel.attributedText = model.rateText?.withTextStyle(.body1, color: .Text.secondary)
        rateShimmerView.isHidden = hasRate
        hasRate ? rateShimmerView.stopAnimation() : rateShimmerView.startAnimation()

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
        fromImageViewOverlay.configuration = fromConfig
        toImageViewOverlay.configuration = toConfig

        startSwapAnimationIfNeeded()
    }

    private func startSwapAnimationIfNeeded() {
        guard !isSwapAnimationRunning, bounds.width > 0, !rateLabel.isHidden else { return }

        isSwapAnimationRunning = true
        performSwapAnimationLoop(firstTime: true)
    }

    private func performSwapAnimationLoop(firstTime: Bool) {
        let swapOffset = Constants.imageCenterOffset * 2

        func animateSwap(forward: Bool, completion: @escaping () -> Void) {
            let delay: TimeInterval
            let fromTranslationX = forward ? swapOffset : 0
            let toTranslationX = forward ? -swapOffset : 0

            if firstTime, forward {
                delay = 0.3
            } else {
                delay = forward ? 2 : 0.3
            }

            UIView.animateKeyframes(
                withDuration: forward ? 0.75 : 0.4,
                delay: delay,
                options: [.calculationModeCubic],
                animations: {
                    UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                        let fromTransform = CGAffineTransform(translationX: fromTranslationX / 2, y: 0)
                            .scaledBy(x: forward ? 0 : 0, y: forward ? 0.85 : 1)
                        let toTransform = CGAffineTransform(translationX: toTranslationX / 2, y: 0)
                            .scaledBy(x: forward ? -1.15 : 0, y: forward ? 1.15 : 1)
                        self.fromImageView.transform = fromTransform
                        self.toImageView.transform = toTransform
                        self.fromImageViewOverlay.transform = fromTransform
                        self.toImageViewOverlay.transform = toTransform
                    }
                    UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                        let fromTransform = CGAffineTransform(translationX: fromTranslationX, y: 0)
                        let toTransform = CGAffineTransform(translationX: toTranslationX, y: 0)
                        self.fromImageView.transform = fromTransform
                        self.toImageView.transform = toTransform
                        self.fromImageViewOverlay.transform = fromTransform
                        self.toImageViewOverlay.transform = toTransform
                    }
                    UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.2) {
                        self.fromImageView.alpha = forward ? 0 : 1
                        self.toImageView.alpha = forward ? 0 : 1
                        self.fromImageViewOverlay.alpha = forward ? 1 : 0
                        self.toImageViewOverlay.alpha = forward ? 1 : 0
                    }
                },
                completion: { _ in completion() }
            )
        }

        animateSwap(forward: true) { [weak self] in
            animateSwap(forward: false) {
                self?.performSwapAnimationLoop(firstTime: false)
            }
        }
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
        static let receiveLabelTopOffset: CGFloat = 4
        static let rateLabelTopOffset: CGFloat = 4
        static let rateShimmerWidth: CGFloat = 136
        static let rateShimmerHeight: CGFloat = 24
        static let configurationImageSize: CGFloat = 72
        static let borderWidth: CGFloat = 4
    }
}
