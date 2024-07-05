import UIKit
import TKUIKit

final class NotificationBannerCell: UICollectionViewCell, ConfigurableView {
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
}
