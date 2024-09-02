import UIKit
import TKUIKit

final class NotificationBannerCell: UICollectionViewCell {
  struct Configuration {
    let bannerViewConfiguration: NotificationBannerView.Model
    
    init(bannerViewConfiguration: NotificationBannerView.Model) {
      self.bannerViewConfiguration = bannerViewConfiguration
    }
  }
  
  public var configuration = Configuration(
    bannerViewConfiguration: NotificationBannerView.Model(
      title: nil,
      caption: nil,
      appearance: .regular,
      closeButton: nil
    )) {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  let bannerView = NotificationBannerView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: NotificationBannerView.Model) {
    bannerView.configure(model: model)
  }
  
  private func setup() {
    contentView.addSubview(bannerView)
    bannerView.snp.makeConstraints { make in
      make.edges.equalTo(contentView)
    }
  }
  
  private func didUpdateConfiguration() {
    bannerView.configure(model: configuration.bannerViewConfiguration)
  }
}
