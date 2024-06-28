import UIKit
import TKUIKit

final class TonConnectConnectWalletButton: UIControl, ConfigurableView {
  override var isHighlighted: Bool {
    didSet {
      highlightView.isHighlighted = isHighlighted
    }
  }
  
  let highlightView = TKHighlightView()
  let contentView = TKUIListItemView()
  let switchView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .center
    imageView.image = .TKUIKit.Icons.Size16.switch
    imageView.tintColor = .Icon.secondary
    return imageView
  }()
  
  let padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
  
  func configure(model: TKUIListItemView.Configuration) {
    contentView.configure(configuration: model)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    layer.cornerRadius = 16
    layer.masksToBounds = true
    contentView.isUserInteractionEnabled = false
    
    backgroundColor = .Background.content
    
    addSubview(highlightView)
    addSubview(contentView)
    addSubview(switchView)
    
    setupConstrainsts()
  }
  
  private func setupConstrainsts() {
    highlightView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    switchView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      highlightView.topAnchor.constraint(equalTo: topAnchor),
      highlightView.leftAnchor.constraint(equalTo: leftAnchor),
      highlightView.bottomAnchor.constraint(equalTo: bottomAnchor),
      highlightView.rightAnchor.constraint(equalTo: rightAnchor),
      
      contentView.topAnchor.constraint(equalTo: topAnchor, constant: padding.top),
      contentView.leftAnchor.constraint(equalTo: leftAnchor, constant: padding.left),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding.bottom).withPriority(.defaultHigh),
      contentView.rightAnchor.constraint(equalTo: switchView.leftAnchor, constant: -16).withPriority(.defaultHigh),
      
      switchView.topAnchor.constraint(equalTo: topAnchor),
      switchView.rightAnchor.constraint(equalTo: rightAnchor, constant: -22).withPriority(.defaultHigh),
      switchView.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
    ])
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 76)
  }
}
