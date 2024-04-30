import UIKit

final class TKResultView: UIView {
  
  enum State {
    case success
    case failure
    
    var tintColor: UIColor {
      switch self {
      case .success: return .Accent.green
      case .failure: return .Accent.red
      }
    }
    
    var title: String? {
      switch self {
      case .success: return "Done"
      case .failure: return "Error"
      }
    }
    
    var icon: UIImage? {
      switch self {
      case .success: return .TKUIKit.Icons.Size32.checkmarkCircle
      case .failure: return .TKUIKit.Icons.Size32.exclamationmarkCircle
      }
    }
  }
  
  var state: State {
    didSet { didChangeState() }
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let iconImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .center
    return imageView
  }()
  
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.label2.font
    label.textAlignment = .center
    return label
  }()
  
  init(state: State) {
    self.state = state
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    stackView.systemLayoutSizeFitting(.zero)
  }
}

private extension TKResultView {
  func setup() {
    addSubview(stackView)
    
    stackView.addArrangedSubview(iconImageView)
    stackView.addArrangedSubview(titleLabel)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
      stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
    ])
    
    didChangeState()
  }
  
  func didChangeState() {
    iconImageView.tintColor = state.tintColor
    iconImageView.image = state.icon
    
    titleLabel.textColor = state.tintColor
    titleLabel.text = state.title
  }
}

