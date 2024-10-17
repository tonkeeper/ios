import UIKit
import TKUIKit

struct TonConnectConnectNotificationTickComponent: TKPopUp.Item {
  func getView() -> UIView {
    let view = TonConnectConnectNotificationTickView()
    view.configuration = configuration
    return view
  }
  
  private let configuration: TonConnectConnectNotificationTickView.Configuration
  public let bottomSpace: CGFloat
  
  init(configuration: TonConnectConnectNotificationTickView.Configuration,
       bottomSpace: CGFloat) {
    self.configuration = configuration
    self.bottomSpace = bottomSpace
  }
}

final class TonConnectConnectNotificationTickView: UIControl {
  
  struct Configuration {
    let text: NSAttributedString?
    let isOn: Bool
    let action: ((Bool) -> Void)?
  }
  
  var configuration = Configuration(text: nil, isOn: true, action: nil) {
    didSet {
      textLabel.attributedText = configuration.text
      tickView.isSelected = configuration.isOn
    }
  }
  
  override var isHighlighted: Bool {
    didSet {
      tickView.alpha = isHighlighted ? 0.48 : 1
    }
  }
  
  let backgroundView = UIView()
  let textLabel = UILabel()
  let tickView = TKTickView()
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
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
  
  private func setup() {
    backgroundView.isUserInteractionEnabled = false
    backgroundView.backgroundColor = .Background.content
    backgroundView.layer.cornerRadius = 16
    backgroundView.layer.cornerCurve = .continuous
    
    addSubview(backgroundView)
    backgroundView.addSubview(stackView)
    
    stackView.addArrangedSubview(textLabel)
    stackView.addArrangedSubview(tickView)
    
    setupConstraints()
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.tickView.isSelected.toggle()
      self?.configuration.action?(self?.tickView.isSelected ?? false)
    }), for: .touchUpInside)
  }
  
  private func setupConstraints() {
    tickView.setContentHuggingPriority(.required, for: .horizontal)
    
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(16)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(backgroundView).inset(16)
    }
  }
}
