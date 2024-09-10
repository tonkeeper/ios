import UIKit
import TKUIKit

final class HistoryCellLoaderView: UIView {
  let loaderView = TKLoaderView(size: .xSmall, style: .primary)
  let loaderBackgroundView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: 22, height: 22)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    loaderBackgroundView.frame = CGRect(x: 2, y: 2, width: 18, height: 18)
    loaderView.sizeToFit()
    loaderView.center = CGPoint(x: loaderBackgroundView.bounds.width/2, y: loaderBackgroundView.bounds.height/2)
  }
  
  func startAnimation() {
    loaderView.startAnimation()
  }
  
  func stopAnimation() {
    loaderView.stopAnimation()
  }
}

private extension HistoryCellLoaderView {
  func setup() {
    backgroundColor = .Background.content
    loaderBackgroundView.backgroundColor = .Icon.tertiary
    
    addSubview(loaderBackgroundView)
    loaderBackgroundView.addSubview(loaderView)
    
    layer.masksToBounds = true
    layer.cornerRadius = 11
    
    loaderBackgroundView.layer.masksToBounds = true
    loaderBackgroundView.layer.cornerRadius = 9
  }
}
