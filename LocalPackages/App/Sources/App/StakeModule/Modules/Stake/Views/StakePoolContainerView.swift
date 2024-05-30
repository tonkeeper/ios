import UIKit
import TKUIKit
import TKCore

final class StakePoolContainerView: UIControl, ConfigurableView {
  
  override var isHighlighted: Bool {
    didSet {
      didUpdateIsHighlighted()
    }
  }
  
  private var didTapClosure: (() -> Void)?
  
  private let listItemView = TKUIListItemView()
  private let highlightView = UIView()

  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let icon: TKUIListItemIconView.Configuration
    let content: TKUIListItemContentView.Configuration
    let accessory: TKUIListItemAccessoryView.Configuration
    let selectionClosure: (() -> Void)?
  }
  
  func configure(model: Model) {
    listItemView.configure(
      configuration: TKUIListItemView.Configuration(
        iconConfiguration: model.icon,
        contentConfiguration: model.content,
        accessoryConfiguration: model.accessory
      )
    )
  
    didTapClosure = model.selectionClosure
  }
}

private extension StakePoolContainerView {
  func setup() {
    layer.cornerRadius = 16
    layer.masksToBounds = true
    
    listItemView.isUserInteractionEnabled = false
    highlightView.isUserInteractionEnabled = false

    backgroundColor = .Background.content
    highlightView.backgroundColor = .Background.highlighted
    highlightView.alpha = 0
    
    addSubview(highlightView)
    addSubview(listItemView)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.didTapClosure?()
    }), for: .touchUpInside)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    highlightView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    listItemView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets.contentPadding)
    }
  }
  
  func didUpdateIsHighlighted() {
    highlightView.alpha = isHighlighted ? 1 : 0
  }
}

private extension CGFloat {
  static let height: CGFloat = 76
}

private extension UIEdgeInsets {
  static let contentPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}
