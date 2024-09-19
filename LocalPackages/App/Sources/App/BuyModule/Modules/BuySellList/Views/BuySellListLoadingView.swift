import UIKit
import TKUIKit

final class BuySellListLoadingView: TKView {
  
  let loaderView = TKLoaderView(size: .medium, style: .primary)
  
  override func setup() {
    super.setup()
    
    addSubview(loaderView)
    
    backgroundColor = .Background.page
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    loaderView.snp.makeConstraints { make in
      make.center.equalTo(self)
    }
  }
  
  override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
    CGSize(width: targetSize.width, height: 60)
  }
}

