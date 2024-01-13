import UIKit
import TKUIKit

final class WalletEmojiPickerViewCell: UICollectionViewCell, ConfigurableView {
  
  private let label = UILabel()
  private let textLayer = CATextLayer()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    textLayer.frame = bounds
    CATransaction.commit()
  }

  func configure(model: WalletEmojiPickerView.Model.Item) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    textLayer.string = model.emoji.emoji
    CATransaction.commit()
  }
}

private extension WalletEmojiPickerViewCell {
  func setup() {
    textLayer.fontSize = 36;
    textLayer.alignmentMode = .center
    textLayer.contentsScale = UIScreen.main.scale
    textLayer.actions = ["contents": NSNull()]
    
    layer.addSublayer(textLayer)
  }
}
