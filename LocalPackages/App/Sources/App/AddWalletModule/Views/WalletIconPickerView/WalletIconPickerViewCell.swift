import UIKit
import TKUIKit

final class WalletIconPickerViewCell: UICollectionViewCell, ConfigurableView {
  
  private let label = UILabel()
  private let textLayer = CATextLayer()
  private let imageView = UIImageView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    imageView.frame.size = CGSize(width: 32, height: 32)
    imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    textLayer.frame = bounds
    CATransaction.commit()
  }
  
  enum Model {
    case image(UIImage?)
    case emoji(String)
  }

  func configure(model: Model) {
    switch model {
    case .emoji(let emoji):
      imageView.isHidden = true
      imageView.image = nil
      textLayer.isHidden = false
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      textLayer.string = emoji
      CATransaction.commit()
    case .image(let image):
      imageView.isHidden = false
      imageView.image = image
      textLayer.isHidden = true
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      textLayer.string = nil
      CATransaction.commit()
    }
  }
}

private extension WalletIconPickerViewCell {
  func setup() {
    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .Icon.primary
    
    textLayer.fontSize = 36;
    textLayer.alignmentMode = .center
    textLayer.contentsScale = UIScreen.main.scale
    textLayer.actions = ["contents": NSNull()]
    
    layer.addSublayer(textLayer)
    addSubview(imageView)
  }
}
