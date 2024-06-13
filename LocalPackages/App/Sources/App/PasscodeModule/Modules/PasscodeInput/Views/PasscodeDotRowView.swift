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
//  static let dotsShakeAnimationPositionDiff: CGFloat = 10
}

private extension TimeInterval {
//  static let dotsShakeAnimationDuration: TimeInterval = 0.07
}

private extension Float {
//  static let dotsShakeAnimationRepeatCount: Float = 3
}


//
//final class PasscodeDotRowView: UIView {
//  
//  enum InputState {
//    case input(count: Int)
//  }
//  
//  enum ValidationState {
//    case none
//    case success
//    case failed
//  }
//  
//  var inputState: InputState = .input(count: 0) {
//    didSet {
//      didSetInputState(oldState: oldValue)
//    }
//  }
//  
//  var validationState: ValidationState = .none {
//    didSet {
//      guard validationState != oldValue else { return }
//      if validationState == .failed {
//        layer.add(shakeAnimation, forKey: "position")
//      }
//      updateStateAppearance()
//    }
//  }
//  
//  private let stackView: UIStackView = {
//    let stackView = UIStackView()
//    stackView.axis = .horizontal
//    stackView.distribution = .fillEqually
//    stackView.spacing = .interDotSpace
//    return stackView
//  }()
//  
//  private(set) var dots = [PasscodeDotView]()
//  
//  private lazy var shakeAnimation: CABasicAnimation = {
//    let animation = CABasicAnimation(keyPath: "position")
//    animation.duration = .dotsShakeAnimationDuration
//    animation.repeatCount = .dotsShakeAnimationRepeatCount
//    animation.autoreverses = true
//    animation.fromValue = NSValue(cgPoint: CGPoint(x: center.x - .dotsShakeAnimationPositionDiff, y: center.y))
//    animation.toValue = NSValue(cgPoint: CGPoint(x: center.x + .dotsShakeAnimationPositionDiff, y: center.y))
//    return animation
//  }()
//  
//  override init(frame: CGRect) {
//    super.init(frame: frame)
//    setup()
//  }
//  
//  required init?(coder: NSCoder) {
//    fatalError("init(coder:) has not been implemented")
//  }
//}
//
//private extension PasscodeDotRowView {
//  func setup() {
//    
//    (0..<4).forEach { _ in
//      let dotView = PasscodeDotView()
//      dots.append(dotView)
//      stackView.addArrangedSubview(dotView)
//    }
//    
//    addSubview(stackView)
//    
//    setupConstraints()
//    
//    updateStateAppearance()
//  }
//  
//  func setupConstraints() {
//    stackView.translatesAutoresizingMaskIntoConstraints = false
//    
//    NSLayoutConstraint.activate([
//      stackView.topAnchor.constraint(equalTo: topAnchor),
//      stackView.leftAnchor.constraint(equalTo: leftAnchor),
//      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
//      stackView.rightAnchor.constraint(equalTo: rightAnchor)
//    ])
//  }
//  
//  func updateStateAppearance() {
//    switch inputState {
//    case let .input(count):
//      dots.enumerated().forEach {
//        if $0 > count - 1 {
//          $1.state = .empty
//        } else {
//          let dotState: PasscodeDotView.State
//          switch validationState {
//          case .none:
//            dotState = .filled
//          case .success:
//            dotState = .success
//          case .failed:
//            dotState = .failed
//          }
//          $1.state = dotState
//        }
//      }
//    }
//  }
//  
//  func didSetInputState(oldState: InputState) {
//    switch (oldState, inputState) {
//    case (.input(let oldCount), .input(let newCount)):
//      let diff = newCount - oldCount
//      var count = oldCount
//      Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
//        count += diff
//        if count < 0 {
//          timer.invalidate()
//        }
//      }
////      break
//    }
////    func reset(animated: Bool, completion: @escaping () -> Void) {
////      guard animated else {
////        validationState = .none
////        inputState = .input(count: 0)
////        completion()
////        return
////      }
////      
////      var count = dots.count
////      Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
////        self?.inputState = .input(count: count)
////        count -= 1
////        if count < 0 {
////          timer.invalidate()
////          completion()
////        }
////      }
////    }
//  }
//}
//
//private extension CGFloat {
//  static let side: CGFloat = 12
//  static let bigSide: CGFloat = 16
//  static let interDotSpace: CGFloat = 16
//  static let dotsShakeAnimationPositionDiff: CGFloat = 10
//}
//
//private extension TimeInterval {
//  static let dotsShakeAnimationDuration: TimeInterval = 0.07
//}
//
//private extension Float {
//  static let dotsShakeAnimationRepeatCount: Float = 3
//}
