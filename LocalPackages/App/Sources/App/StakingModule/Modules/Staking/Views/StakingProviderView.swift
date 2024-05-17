import UIKit
import TKUIKit

final class StakingProviderView: UIControl, ConfigurableView {
  private let listItemView = TKUIListItemView()
  private let separatorView = TKSeparatorView()
  
  override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      didUpdateIsHighlighted()
    }
  }
  
  struct Model {
    let image: TKUIListItemImageIconView.Configuration.Image
    let title: String
    let subtitle: String
    let tagText: String?
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    listItemView.frame = CGRect(
      x: .contentPadding,
      y: .contentPadding,
      width: bounds.width - .contentPadding * 2,
      height: bounds.height - .contentPadding * 2
    )
  
    invalidateIntrinsicContentSize()
  }
  
  override var intrinsicContentSize: CGSize {
    let fitSize = listItemView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    return CGSize(width: fitSize.width, height: fitSize.height + 2 * .contentPadding)
  }
  
  func configure(model: Model) {
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        .init(
          image: model.image,
          tintColor: .clear,
          backgroundColor: .clear,
          size: .init(width: 44, height: 44),
          cornerRadius: 22
        )
      ),
      alignment: .center
    )
    
    var tagConfiguration: TKUITagView.Configuration?
    if let tagText = model.tagText {
      tagConfiguration = TKUITagView.Configuration(
        text: tagText,
        textColor: .Accent.green,
        backgroundColor: .Accent.green.withAlphaComponent(0.3)
      )
    }
    
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: model.title.withTextStyle(.label1, color: .Text.primary),
      tagViewModel: tagConfiguration,
      subtitle: model.subtitle.withTextStyle(.body2, color: .Text.secondary),
      description: nil
    )
    
    listItemView.configure(
      configuration: .init(
        iconConfiguration: iconConfiguration,
        contentConfiguration: .init(
          leftItemConfiguration: leftItemConfiguration,
          rightItemConfiguration: nil
        ),
        accessoryConfiguration: .image(
          .init(
            image: .TKUIKit.Icons.Size16.switch,
            tintColor: .Text.tertiary,
            padding: .zero
          )
        )
      )
    )
    
    setNeedsLayout()
  }
  
  func didUpdateIsHighlighted() {
    backgroundColor = isHighlighted ? .Background.highlighted : .Background.content
  }
}

private extension StakingProviderView {
  func setup() {
    listItemView.isUserInteractionEnabled = false
    
    backgroundColor = .Background.content
    layer.cornerRadius = .cornerRadius
    
    addSubview(listItemView)
  }
}

private extension CGFloat {
  static let contentPadding: Self = 16
  static let cornerRadius: Self = 16
}
