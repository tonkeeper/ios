import UIKit

final class PasscodeDotRowView: UIView {
  enum ValidationState {
    case none
    case success
    case failed
  }

  var inputLength = 4 {
    didSet {
      setupDots()
      inputCount = 0
      validationState = .none
    }
  }
  
  var inputCount = 0 {
    didSet {
      update(inputCount: inputCount, validationState: validationState)
    }
  }
  
  var validationState = ValidationState.none {
    didSet {
      update(inputCount: inputCount, validationState: validationState)
    }
  }

  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .fillEqually
    stackView.spacing = .interDotSpace
    return stackView
  }()
  
  private(set) var dots = [PasscodeDotView]()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension PasscodeDotRowView {
  func setup() {
    setupDots()
    
    addSubview(stackView)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    update(inputCount: inputCount, validationState: validationState)
  }
  
  func setupDots() {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    dots = []
    
    (0..<inputLength).forEach { _ in
      let dotView = PasscodeDotView()
      dots.append(dotView)
      stackView.addArrangedSubview(dotView)
    }
  }
  
  func update(inputCount: Int, validationState: ValidationState) {
    dots.enumerated().forEach { index, dot in
      if index < inputCount {
        let dotState: PasscodeDotView.State
        switch validationState {
        case .none:
          dotState = .filled
        case .success:
          dotState = .success
        case .failed:
          dotState = .failed
        }
        
        dot.state = dotState
      } else {
        dot.state = .empty
      }
    }
  }
}

private extension CGFloat {
  static let side: CGFloat = 12
  static let bigSide: CGFloat = 16
  static let interDotSpace: CGFloat = 16
}
