import UIKit

public final class TKUIListItemButton: UIControl, ConfigurableView {
  
  public override var isHighlighted: Bool {
    didSet {
      hightlightView.isHighlighted = isHighlighted
    }
  }
  
  private var tapClosure: (() -> Void)?
  
  private let hightlightView = TKHighlightView()
  private let listItemView = TKUIListItemView()
  
  public struct Model {
    public let listItemConfiguration: TKUIListItemView.Configuration
    public let tapClosure: (() -> Void)?
    
    public init(listItemConfiguration: TKUIListItemView.Configuration, tapClosure: (() -> Void)?) {
      self.listItemConfiguration = listItemConfiguration
      self.tapClosure = tapClosure
    }
  }
  
  public func configure(model: Model) {
    listItemView.configure(configuration: model.listItemConfiguration)
    self.tapClosure = model.tapClosure
    self.isUserInteractionEnabled = model.tapClosure != nil
  }
  
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
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.tapClosure?()
    }), for: .touchUpInside)
    
    listItemView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(16)
    }
    
    hightlightView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
