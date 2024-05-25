import UIKit
import TKUIKit

final class StakingProviderView: UIControl, ConfigurableView {
  private let container: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.backgroundColor = .Background.content
    container.padding = .contentPadding
    
    return container
  }()
  
  private let label: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    
    return label
  }()
  
  private let listItemView = TKUIListItemView()
  
  private var model: Model? {
    didSet {
      guard let model else { return }
      switch model {
      case .listItem(let configuration):
        container.isUserInteractionEnabled = false
        didUpdateListItemConfiguration(configuration)
      case .text(let text):
        container.isUserInteractionEnabled = true
        didUpdateText(text)
      }
    }
  }
  
//  var listItemConfiguration: TKUIListItemView.Configuration? {
//    didSet {
//      container.isUserInteractionEnabled = false
//      didUpdateListItemConfiguration(listItemConfiguration)
//    }
//  }
//  
//  var text: NSAttributedString? {
//    didSet {
//      container.isUserInteractionEnabled = true
//      didUpdateText(text)
//    }
//  }
  
  override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      didUpdateIsHighlighted()
    }
  }
  
  enum Model: Hashable {
    case listItem(TKUIListItemView.Configuration)
    case text(NSAttributedString)
  }
  
  func configure(model: Model) {
    self.model = model
  }
//  
//  struct Model {
//    let image: TKUIListItemImageIconView.Configuration.Image
//    let title: String
//    let subtitle: String
//    let tagText: String?
//  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    container.layer.cornerRadius = .cornerRadius
  }
  
  func didUpdateIsHighlighted() {
    container.backgroundColor = isHighlighted ? .Background.highlighted : .Background.content
  }
}

private extension StakingProviderView {
  func setup() {
    container.fill(in: self)
  }
  
  func didUpdateListItemConfiguration(_ configuration: TKUIListItemView.Configuration?) {
    guard let configuration else {
      return
    }
    
    if container.stackView.arrangedSubviews.isEmpty {
      container.setViews([listItemView])
    } else {
      if !(container.stackView.arrangedSubviews[0] is TKUIListItemView) {
        container.setViews([listItemView])
      }
    }
    
    listItemView.configure(configuration: configuration)
  }
  
  func didUpdateText(_ text: NSAttributedString?) {
    if container.stackView.arrangedSubviews.isEmpty {
      container.setViews([label])
    } else {
      if !(container.stackView.arrangedSubviews[0] is UILabel) {
        container.setViews([label])
      }
    }
    
    label.attributedText = text
  }
}

private extension CGFloat {
  static let cornerRadius: Self = 16
}

private extension UIEdgeInsets {
  static let contentPadding = UIEdgeInsets(
    top: 16,
    left: 16,
    bottom: 16,
    right: 16
  )
}
