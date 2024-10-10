import UIKit

public enum TKListContainerItemAction {
  case copy(copyValue: String?)
  case custom(() -> Void)
}

public protocol TKListContainerItem {
  var action: TKListContainerItemAction? { get }
  
  func getView() -> UIView
}

public protocol TKListContainerReconfigurableItem: TKListContainerItem {
  var id: String? { get }
  func reconfigure(view: UIView)
}

public final class TKListContainerView: UIView {
  
  public struct Configuration {
    public let items: [TKListContainerItem]
    public init(items: [TKListContainerItem]) {
      self.items = items
    }
  }
  
  public var configuration: Configuration? {
    didSet {
      setup(with: configuration)
    }
  }
  
  private var contentViews = [String: UIView]()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.content
    view.layer.masksToBounds = true
    view.layer.cornerRadius = 16
    return view
  }()

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(backgroundView)
    backgroundView.addSubview(stackView)
    
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    stackView.snp.makeConstraints { make in
      make.top.bottom.equalTo(backgroundView)
      make.left.right.equalTo(backgroundView)
    }
  }
  
  private func setup(with configuration: Configuration?) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    guard let configuration else { return }
    configuration.items.forEach { item in
      
      let createView = { (id: String?) in
        let contentView = item.getView()
        contentView.isUserInteractionEnabled = false
        let itemView = TKListContainerItemViewContainer()
        itemView.setContentView(contentView)
        if let action = item.action {
          itemView.isHighlightable = true
          itemView.addAction(UIAction(handler: { _ in
            switch action {
            case .copy(let copyValue):
              guard let copyValue = copyValue else { return }
              UIPasteboard.general.string = copyValue
              UINotificationFeedbackGenerator().notificationOccurred(.warning)
              ToastPresenter.showToast(configuration: .copied)
            case .custom(let action):
              action()
            }
          }), for: .touchUpInside)
        } else {
          itemView.isHighlightable = false
        }
        if let id {
          self.contentViews[id] = contentView
        }
        return itemView
      }

      if let reconfigurable = item as? TKListContainerReconfigurableItem {
        if let id = reconfigurable.id, let view = contentViews[id] {
          reconfigurable.reconfigure(view: view)
        } else {
          let view = createView(reconfigurable.id)
          stackView.addArrangedSubview(view)
        }
      } else {
        let view = createView(nil)
        stackView.addArrangedSubview(view)
      }
    }
  }
}
