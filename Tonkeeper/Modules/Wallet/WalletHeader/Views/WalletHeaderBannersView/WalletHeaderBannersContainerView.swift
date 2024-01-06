import UIKit
import TKUIKitLegacy

final class WalletHeaderBannersContainerView: UIView {
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private var bannerViews = [String: WalletHeaderBannerView]()
  private var hideClosures = [String: () -> Void]()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func showBanner(model: WalletHeaderBannerModel,
                  hideClosure: @escaping () -> Void) {
    hideClosures[model.identifier] = hideClosure
    if let bannerView = bannerViews[model.identifier] {
      bannerView.configure(model: model)
    } else {
      let bannerView = WalletHeaderBannerView()
      bannerView.didTapCloseButton = { [weak self] in
        self?.hideBanner(identifier: model.identifier)
      }
      bannerView.configure(model: model)
      stackView.addArrangedSubview(bannerView)
      bannerView.alpha = 0
      bannerViews[model.identifier] = bannerView
      
      UIView.animate(withDuration: 0.2,
                     delay: 0,
                     options: .curveEaseInOut) {
        bannerView.alpha = 1
      }
    }
  }
  
  func hideBanner(identifier: String, completion: (() -> Void)? = nil) {
    UIView.animate(withDuration: 0.2,
                   delay: 0,
                   options: .curveEaseInOut) {
      self.bannerViews[identifier]?.alpha = 0
    } completion: { _ in
      self.bannerViews[identifier]?.removeFromSuperview()
      self.hideClosures[identifier]?()
      self.bannerViews[identifier] = nil
      self.hideClosures[identifier] = nil
      completion?()
    }
  }
}

private extension WalletHeaderBannersContainerView {
  func setup() {
    addSubview(stackView)
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
