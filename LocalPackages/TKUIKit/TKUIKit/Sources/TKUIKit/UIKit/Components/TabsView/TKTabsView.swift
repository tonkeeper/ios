import UIKit

public final class TKTabsView: UIView {
  public struct Item {
    public let title: String
    public let isSelectable: Bool
    public let action: () -> Void
    public init(title: String, isSelectable: Bool, action: @escaping () -> Void) {
      self.title = title
      self.isSelectable = isSelectable
      self.action = action
    }
  }
  
  public var items = [Item]() {
    didSet {
      tabButtons = []
      stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
      items.forEach { item in
        let button = TKTabButton()
        button.title = item.title
        button.action = { [weak self] in
          self?.didTapItem(item: item, button: button)
        }
        stackView.addArrangedSubview(button)
        tabButtons.append(button)
      }
    }
  }
  
  private var tabButtons = [TKTabButton]()
  private let stackView = UIStackView()
  private let scrollView = UIScrollView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override var intrinsicContentSize: CGSize {
    return CGSize(width: UIView.noIntrinsicMetric, height: 56)
  }
  
  private func setup() {
    backgroundColor = .Background.page
    
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    
    stackView.alignment = .center
    stackView.spacing = 8
    
    addSubview(scrollView)
    scrollView.addSubview(stackView)
    
    scrollView.snp.makeConstraints { make in
      make.top.equalTo(self).offset(8)
      make.left.right.bottom.equalTo(self).inset(16)
    }
    stackView.snp.makeConstraints { make in
      make.top.equalTo(scrollView)
      make.left.bottom.equalTo(scrollView)
      make.right.lessThanOrEqualTo(scrollView)
      make.height.equalTo(scrollView)
    }
  }
  
  private func didTapItem(item: Item, button: TKTabButton) {
    tabButtons.forEach {
      $0.isSelected = $0 === button && item.isSelectable
    }
    item.action()
  }
}

private final class TKTabButton: UIControl {
  private let button = TKButton()
  
  override var isSelected: Bool {
    didSet {
      button.isSelected = isSelected
    }
  }
  
  var action: (() -> Void)? {
    didSet {
      updateButtonConfiguration()
    }
  }
  
  var title: String? {
    didSet {
      updateButtonConfiguration()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func updateButtonConfiguration() {
    var configuration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .small)
    configuration.backgroundColors[.selected] = .Button.primaryBackgroundHighlighted
    configuration.content.title = .plainString(title ?? "")
    configuration.action = { [weak self] in
      self?.action?()
    }
    button.configuration = configuration
  }
  
  private func setup() {
    addSubview(button)
    button.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
