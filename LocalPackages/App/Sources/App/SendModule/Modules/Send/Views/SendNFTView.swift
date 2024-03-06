import UIKit
import TKUIKit
import SnapKit

final class SendNFTView: UIControl, ConfigurableView {
  
  private let nftView = NFTView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let nftViewModel: NFTView.Model
    
    init(nftViewModel: NFTView.Model) {
      self.nftViewModel = nftViewModel
    }
  }
  
  func configure(model: Model) {
    nftView.configure(model: model.nftViewModel)
  }
}

private extension SendNFTView {
  func setup() {
    layer.cornerRadius = 16
    layer.masksToBounds = true
    backgroundColor = .Background.content
    
    nftView.isUserInteractionEnabled = false
    
    addSubview(nftView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    nftView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(40)
      make.height.equalTo(64)
    }
  }
}
