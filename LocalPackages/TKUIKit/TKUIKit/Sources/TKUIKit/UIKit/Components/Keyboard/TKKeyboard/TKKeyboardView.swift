import UIKit

public final class TKKeyboardView: UIView {
  
  public var didTapDigit: ((Int) -> Void)?
  public var didTapBackspace: (() -> Void)?
  public var didTapBiometry: (() -> Void)?
  public var didTapDecimalSeparator: (() -> Void)?
  
  public var configuration: TKKeyboardView.Configuration {
    didSet {
      setupConfiguration()
    }
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private var touchedDownButton: TKUIPlainKeyboardButton?
  private var backspaceTimer: Timer?
  
  public init(configuration: TKKeyboardView.Configuration) {
    self.configuration = configuration
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension TKKeyboardView {
  func setup() {
    addSubview(stackView)
    
    setupConstraints()
    setupConfiguration()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
  
  func setupConfiguration() {
    self.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    
    for row in configuration.rows {
      let rowStackView = UIStackView()
      rowStackView.distribution = .fillEqually
      self.stackView.addArrangedSubview(rowStackView)
      
      for button in row.buttons {
        switch button {
        case .digit(let digit):
          let keyboardButton = createButton { [weak self] in
            self?.didTapDigit?(digit)
          }
          keyboardButton.configure(model: .text("\(digit)"))
          rowStackView.addArrangedSubview(keyboardButton)
        case .backspace:
          let keyboardButton = createButton { [weak self] in
            self?.didTapBackspace?()
          }
          keyboardButton.configure(model: .image(.TKUIKit.Icons.Size36.delete))
          addLongTapGesture(button: keyboardButton)
          rowStackView.addArrangedSubview(keyboardButton)
        case .decimalSeparator:
          let keyboardButton = createButton { [weak self] in
            self?.didTapDecimalSeparator?()
          }
          keyboardButton.configure(model: .text(Locale.current.decimalSeparator ?? "."))
          rowStackView.addArrangedSubview(keyboardButton)
        case .biometry(let biometry):
          let keyboardButton = createButton { [weak self] in
            self?.didTapBiometry?()
          }
          keyboardButton.configure(model: .image(biometry.image))
          rowStackView.addArrangedSubview(keyboardButton)
        case .empty:
          let view = UIView()
          rowStackView.addArrangedSubview(view)
        }
      }
    }
  }
  
  func createButton(action: @escaping () -> Void) -> TKUIPlainKeyboardButton {
    let button = TKUIPlainKeyboardButton()
    
    button.addAction(UIAction(handler: { [weak self] _ in
      if let touchedDownButton = self?.touchedDownButton {
        touchedDownButton.cancelTracking(with: nil)
        action()
      }
      self?.touchedDownButton = button
    }), for: .touchDown)
    
    button.addAction(UIAction(handler: { _ in
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      self.touchedDownButton = nil
      action()
    }), for: .touchUpInside)
    
    button.addAction(UIAction(handler: { [weak self] _ in
      self?.touchedDownButton = nil
    }), for: .touchDragExit)
    
    button.addAction(UIAction(handler: { [weak self] _ in
      self?.touchedDownButton = nil
    }), for: .touchCancel)
    
    return button
  }
  
  func addLongTapGesture(button: TKUIPlainKeyboardButton) {
    let gesture = UILongPressGestureRecognizer(target: self, action: #selector(didLongTap(gestureRecognizer:)))
    gesture.minimumPressDuration = 0.2
    button.addGestureRecognizer(gesture)
  }
  
  @objc
  func didLongTap(gestureRecognizer: UILongPressGestureRecognizer) {
    switch gestureRecognizer.state {
    case .began:
      backspaceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
        self?.didTapBackspace?()
      }
    case .ended, .cancelled, .failed:
      backspaceTimer?.invalidate()
    default:
      break
    }
  }
}
