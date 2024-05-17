import UIKit

final class TKPopupMenuItemView: UIControl, ConfigurableView {
  
  var didTap: (() -> Void)?
  
  let titleLabel = UILabel()
  let valueLabel = UILabel()
  let rightIconImageView = UIImageView()
  let selectionView = UIImageView()
  let highlightView = TKHighlightView()
  
  override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      highlightView.isHighlighted = isHighlighted
    }
  }
  
  override var isSelected: Bool {
    didSet {
      guard isSelected != oldValue else { return }
      selectionView.alpha = isSelected ? 1 : 0
    }
  }
  
  private let labelTopStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 8
    return stackView
  }()
  
  private let labelStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 8
    stackView.alignment = .center
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let title: NSAttributedString
    let value: NSAttributedString?
    let description: NSAttributedString?
    let icon: UIImage?
    let isSelectable: Bool
    let selectionHandler: (() -> Void)?
    
    init(title: String,
         value: String?,
         description: String?,
         icon: UIImage?,
         isSelectable: Bool,
         selectionHandler: (() -> Void)? = nil) {
      self.title = title.withTextStyle(.label1, color: .Text.primary)
      self.value = value?.withTextStyle(.body1, color: .Text.secondary)
      self.description = description?.withTextStyle(.body2, color: .Text.secondary)
      self.icon = icon
      self.isSelectable = isSelectable
      self.selectionHandler = selectionHandler
    }
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    valueLabel.attributedText = model.value
    rightIconImageView.image = model.icon
    rightIconImageView.isHidden = model.icon == nil
    selectionView.isHidden = !model.isSelectable
    
    setNeedsLayout()
    invalidateIntrinsicContentSize()
  }
}

private extension TKPopupMenuItemView {
  func setup() {
    addAction(UIAction(handler: { [weak self] _ in
      self?.didTap?()
    }), for: .touchUpInside)
    
    backgroundColor = .Background.contentTint
    
    selectionView.image = .TKUIKit.Icons.Size16.doneBold
    selectionView.tintColor = .Accent.blue
    selectionView.alpha = isSelected ? 1 : 0
    
    stackView.isUserInteractionEnabled = false
    
    addSubview(highlightView)
    addSubview(stackView)
    stackView.addArrangedSubview(labelStackView)
    stackView.addArrangedSubview(rightIconImageView)
    stackView.addArrangedSubview(selectionView)
    labelStackView.addArrangedSubview(labelTopStackView)
    labelTopStackView.addArrangedSubview(titleLabel)
    labelTopStackView.addArrangedSubview(valueLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    highlightView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    stackView.snp.makeConstraints { make in
      make.top.bottom.equalTo(self).inset(12)
      make.left.right.equalTo(self).inset(16)
    }
    
    selectionView.snp.makeConstraints { make in
      make.width.equalTo(16)
    }
  }
}

