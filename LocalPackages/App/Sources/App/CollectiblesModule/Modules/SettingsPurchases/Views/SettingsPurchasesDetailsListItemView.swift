import UIKit
import TKUIKit

final class SettingsPurchasesDetailsListItemView: UIView, ConfigurableView {
  
  private let imageView = TKImageView()
  private let titleLabel = UILabel()
  private let captionLabel = UILabel()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  private let labelsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  struct Model: TKListContainerItem {
    var isHighlightable: Bool
    var copyValue: String?
    
    func getView() -> UIView {
      let view = SettingsPurchasesDetailsListItemView()
      view.configure(model: self)
      return view
    }
    
    let title: NSAttributedString
    let caption: NSAttributedString?
    let image: TKImageView.Model?
    
    init(title: String,
         caption: String?,
         image: TKImageView.Model? = nil,
         isHighlightable: Bool = true,
         copyValue: String?) {
      self.title = title.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      self.caption = caption?.withTextStyle(
        .body2,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      self.image = image
      self.isHighlightable = isHighlightable
      self.copyValue = copyValue
    }
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    captionLabel.attributedText = model.caption
    
    if let image = model.image {
      stackView.addArrangedSubview(imageView)
      imageView.configure(model: image)
    } else {
      stackView.removeArrangedSubview(imageView)
    }
    setNeedsLayout()
    invalidateIntrinsicContentSize()
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(labelsStackView)
    
    imageView.setContentHuggingPriority(.required, for: .horizontal)
    
    labelsStackView.addArrangedSubview(titleLabel)
    labelsStackView.addArrangedSubview(captionLabel)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
    }
  }
}
