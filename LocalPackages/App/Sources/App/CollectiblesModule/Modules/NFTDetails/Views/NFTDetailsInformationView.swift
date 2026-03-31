import AVKit
import TKLottieWebView
import TKUIKit
import UIKit

final class NFTDetailsInformationView: UIView, ConfigurableView {
    struct Model {
        enum Item {
            case image(TKImageView.Model)
            case lottieAnimation(URL)
        }

        let image: TKImageView.Model
        let lottieAnimation: URL?
        let isBlurVisible: Bool
        let itemInformationViewModel: NFTDetailsItemInformationView.Model
        let collectionInformationViewModel: NFTDetailsCollectionInformationView.Model?
    }

    func configure(model: Model) {
        imageItemContainerView.subviews.forEach { $0.removeFromSuperview() }

        let imageView = TKImageView()
        imageItemContainerView.insertSubview(imageView, belowSubview: imageBlurView)
        imageView.configure(model: model.image)
        imageView.snp.makeConstraints { make in
            make.edges.equalTo(imageItemContainerView)
        }

        if let lottieAnimation = model.lottieAnimation {
            let lottieWebView = TKLottieWebView()
            lottieWebView.onLoaded = { [weak lottieWebView, weak imageView] in
                lottieWebView?.isHidden = false
                imageView?.isHidden = true
            }
            lottieWebView.onError = { [weak lottieWebView, weak imageView] _ in
                lottieWebView?.isHidden = true
                imageView?.isHidden = false
            }
            lottieWebView.isHidden = true
            imageItemContainerView.insertSubview(lottieWebView, belowSubview: imageBlurView)
            lottieWebView.loadLottieAnimation(url: lottieAnimation)
            lottieWebView.snp.makeConstraints { make in
                make.edges.equalTo(imageItemContainerView)
            }
        }

        imageBlurView.isHidden = !model.isBlurVisible
        itemInformationView.configure(model: model.itemInformationViewModel)
        if let collectionInformationViewModel = model.collectionInformationViewModel {
            separatorView.isHidden = false
            collectionInformationView.isHidden = false
            collectionInformationView.configure(model: collectionInformationViewModel)
        } else {
            separatorView.isHidden = true
            collectionInformationView.isHidden = true
        }
    }

    private let containerView = UIView()
    private let imageItemContainerView = UIView()
    private let imageBlurView = TKSecureBlurView()
    private let itemInformationView = NFTDetailsItemInformationView()
    private let separatorView = TKSeparatorView()
    private let collectionInformationView = NFTDetailsCollectionInformationView()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
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
        containerView.backgroundColor = .Background.content
        containerView.layer.masksToBounds = true
        containerView.layer.cornerRadius = 16
        containerView.layer.cornerCurve = .continuous

        imageBlurView.isHidden = true

        addSubview(containerView)
        containerView.addSubview(stackView)
        stackView.addArrangedSubview(imageItemContainerView)
        stackView.addArrangedSubview(itemInformationView)
        stackView.addArrangedSubview(separatorView)
        stackView.addArrangedSubview(collectionInformationView)
        imageItemContainerView.addSubviews(imageBlurView)

        setupConstraints()
    }

    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.top.equalTo(self)
            make.left.right.equalTo(self).inset(16)
            make.bottom.equalTo(self).offset(-16)
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(containerView)
        }

        imageItemContainerView.snp.makeConstraints { make in
            make.height.equalTo(imageItemContainerView.snp.width)
        }

        imageBlurView.snp.makeConstraints { make in
            make.edges.equalTo(imageItemContainerView)
        }
    }
}
