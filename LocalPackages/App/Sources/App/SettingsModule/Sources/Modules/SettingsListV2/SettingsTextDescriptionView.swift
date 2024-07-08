import UIKit
import TKUIKit

final class SettingsTextDescriptionView: UIView, ReusableView, TKCollectionViewSupplementaryContainerViewContentView {
  
  private var padding: UIEdgeInsets = .zero
  private let textLabel = UILabel()
  
  struct Model: Hashable {
    let padding: UIEdgeInsets
    let text: String?
    let numberOfLines: Int
    
    init(padding: UIEdgeInsets, 
         text: String?,
         numberOfLines: Int = 0) {
      self.padding = padding
      self.text = text
      self.numberOfLines = numberOfLines
    }
  }
  
  func configure(model: Model) {
    self.padding = model.padding
    textLabel.attributedText = model.text?.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    textLabel.numberOfLines = model.numberOfLines
    textLabel.snp.remakeConstraints { make in
      make.edges.equalTo(self).inset(padding).priority(.required.advanced(by: -1))
    }
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    systemLayoutSizeFitting(
      size,
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .defaultLow
    )
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(textLabel)
    
    textLabel.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(padding).priority(.high)
    }
  }
}
