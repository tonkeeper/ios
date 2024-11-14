import UIKit

public final class TKListItemButton: UIControl {
  
  public struct Configuration {
    public let listItemConfiguration: TKListItemContentView.Configuration
    public let accessory: TKListItemAccessory?
    public let isEnable: Bool
    public let tapClosure: (() -> Void)?
    
    public init(listItemConfiguration: TKListItemContentView.Configuration,
                accessory: TKListItemAccessory? = nil,
                isEnable: Bool,
                tapClosure: (() -> Void)?) {
      self.listItemConfiguration = listItemConfiguration
      self.accessory = accessory
      self.isEnable = isEnable
      self.tapClosure = tapClosure
    }
  }
  
  public var configuration = Configuration(
    listItemConfiguration: .default,
    isEnable: false,
    tapClosure: nil
  ) {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  public override var isHighlighted: Bool {
    didSet {
      hightlightView.isHighlighted = isHighlighted
    }
  }
  
  public override var isEnabled: Bool {
    didSet {
      alpha = isEnabled ? 1 : 0.48
    }
  }
  
  private var tapClosure: (() -> Void)?
  
  private let hightlightView = TKHighlightView()
  private let listItemView = TKListItemContentView()
  private let accessoryContainer = UIView()

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    backgroundColor = .Background.content
    layer.cornerRadius = 16
    layer.cornerCurve = .continuous
    layer.masksToBounds = true
    
    listItemView.isUserInteractionEnabled = false
    
    addSubview(hightlightView)
    addSubview(listItemView)
    addSubview(accessoryContainer)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.tapClosure?()
    }), for: .touchUpInside)
    
    listItemView.snp.makeConstraints { make in
      make.top.left.bottom.equalTo(self).inset(16)
      make.right.equalTo(self).inset(16).priority(.high)
      make.right.equalTo(accessoryContainer.snp.left).inset(16)
    }
    
    accessoryContainer.snp.makeConstraints { make in
      make.top.right.bottom.equalTo(self)
    }
    
    hightlightView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
  
  private func didUpdateConfiguration() {
    listItemView.configuration = configuration.listItemConfiguration
    tapClosure = configuration.tapClosure
    isUserInteractionEnabled = configuration.tapClosure != nil && configuration.isEnable
    isEnabled = configuration.isEnable
    
    accessoryContainer.subviews.forEach { $0.removeFromSuperview() }
    if let accessoryView = configuration.accessory?.view {
      accessoryContainer.addSubview(accessoryView)
      accessoryView.snp.makeConstraints { make in
        make.edges.equalTo(accessoryContainer)
      }
    }
  }
}
