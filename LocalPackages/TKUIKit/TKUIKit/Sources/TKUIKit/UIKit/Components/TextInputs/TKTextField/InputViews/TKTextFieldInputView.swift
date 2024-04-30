import UIKit
import SnapKit

public protocol TKTextFieldInputViewControl: UIView {
  var isActive: Bool { get }
  var inputText: String { get set }
  var textFieldState: TKTextFieldState { get set }
  var accessoryView: UIView? { get set }
  var didUpdateText: ((String) -> Void)? { get set }
  var didBeginEditing: (() -> Void)? { get set }
  var didEndEditing: (() -> Void)? { get set }
  var shouldPaste: ((String) -> Bool)? { get set }
}

public final class TKTextFieldInputView: UIControl, TKTextFieldInputViewControl {
  
  public enum ClearButtonMode {
    case never
    case whileEditingNotEmpty
  }
  
  public var clearButtonMode: ClearButtonMode = .whileEditingNotEmpty {
    didSet {
      didSetClearButtonMode()
    }
  }
  
  // MARK: - TKTextFieldInputViewControl
  
  public var isActive: Bool {
    textInputControl.isActive
  }
  public var inputText: String {
    get { textInputControl.inputText }
    set {
      textInputControl.inputText = newValue
      updateTextAction()
    }
  }
  public var textFieldState: TKTextFieldState = .inactive {
    didSet {
      didUpdateState()
    }
  }
  public var accessoryView: UIView? {
    get { textInputControl.accessoryView }
    set { textInputControl.accessoryView = newValue }
  }
  public var didUpdateText: ((String) -> Void)?
  public var didBeginEditing: (() -> Void)?
  public var didEndEditing: (() -> Void)?
  public var shouldPaste: ((String) -> Bool)?
  
  public var padding: UIEdgeInsets = .zero {
    didSet {
      let isActive = textInputControlRightEdgeConstraint?.isActive ?? false
      textInputControl.snp.remakeConstraints { make in
        make.top.left.bottom.equalTo(self).inset(padding)
        textInputControlRightEdgeConstraint = make.right.equalTo(self).inset(padding).constraint
      }
      textInputControlRightEdgeConstraint?.isActive = isActive
    }
  }
  
  // MARK: - Properties
  
  public var placeholder: String = "" {
    didSet {
      placeholderLabel.attributedText = placeholder.withTextStyle(
        .body1,
        color: .Text.secondary,
        alignment: .left
      )
    }
  }
  
  // MARK: - Subviews
  
  private let textInputControl: TKTextFieldInputViewControl
  private lazy var clearButton: TKButton = {
    let button = TKButton()
    button.setContentHuggingPriority(.required, for: .horizontal)
    button.setContentCompressionResistancePriority(.required, for: .horizontal)
    var configuration = TKButton.Configuration.fiedClearButtonConfiguration()
    configuration.action = { [weak self] in
      self?.clearButtonAction()
    }
    button.configuration = configuration
    button.isHidden = true
    return button
  }()
  private let placeholderLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 1
    label.isUserInteractionEnabled = false
    label.layer.anchorPoint = .init(x: 0, y: 0.5)
    return label
  }()
  
  // MARK: - Constraints
  
  private var textInputControlRightEdgeConstraint: Constraint?
  private var textInputControlRightClearButtonConstraint: Constraint?
  
  // MARK: - Init
  
  public init(textInputControl: TKTextFieldInputViewControl) {
    self.textInputControl = textInputControl
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - First Responder
  
  @discardableResult
  public override func becomeFirstResponder() -> Bool {
    textInputControl.becomeFirstResponder()
  }
  
  @discardableResult
  public override func resignFirstResponder() -> Bool {
    textInputControl.resignFirstResponder()
  }
  
  // MARK: - Layout
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    updateTextInputAndPlaceholderLayoutAndScale()
  }
}

private extension TKTextFieldInputView {
  func setup() {
    addSubview(textInputControl)
    addSubview(clearButton)
    addSubview(placeholderLabel)
    
    textInputControl.didUpdateText = { [weak self] in
      guard let self else { return }
      self.inputText = $0
      self.didUpdateText?(self.inputText)
      self.updateTextAction()
    }
    
    textInputControl.didBeginEditing = { [weak self] in
      self?.didBeginEditing?()
      self?.updateClearButtonVisibility()
    }
    
    textInputControl.didEndEditing = { [weak self] in
      self?.didEndEditing?()
      self?.updateClearButtonVisibility()
    }
    
    textInputControl.shouldPaste = { [weak self] in
      self?.shouldPaste?($0) ?? true
    }
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.textInputControl.becomeFirstResponder()
    }), for: .touchUpInside)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    textInputControl.snp.makeConstraints { make in
      make.top.left.bottom.equalTo(self).inset(padding)
      textInputControlRightEdgeConstraint = make.right.equalTo(self).inset(padding).constraint
      textInputControlRightClearButtonConstraint = make.right.equalTo(clearButton.snp.left).constraint
    }
    textInputControlRightClearButtonConstraint?.deactivate()
    
    clearButton.snp.makeConstraints { make in
      make.top.right.bottom.equalTo(self)
    }
  }
  
  func updateClearButtonVisibility() {
    let isClearButtonVisible: Bool
    switch clearButtonMode {
    case .never: 
      isClearButtonVisible = false
    case .whileEditingNotEmpty:
      isClearButtonVisible = !inputText.isEmpty && isActive
    }
    if isClearButtonVisible {
      clearButton.isHidden = false
      textInputControlRightEdgeConstraint?.deactivate()
      textInputControlRightClearButtonConstraint?.activate()
    } else {
      clearButton.isHidden = true
      textInputControlRightClearButtonConstraint?.deactivate()
      textInputControlRightEdgeConstraint?.activate()
    }
  }
  
  func updateTextInputAndPlaceholderLayoutAndScale() {
    updateTextInputControlPosition(isNeedToMove: !placeholder.isEmpty && !inputText.isEmpty)
    updatePlaceholderScaleAndPosition(isTop: !placeholder.isEmpty && !inputText.isEmpty)
  }
  
  func updateTextInputControlPosition(isNeedToMove: Bool) {
    let textInputControlTransform: CGAffineTransform = isNeedToMove ? CGAffineTransform(translationX: 0, y: .inputControlYOffset) : .identity
    textInputControl.transform = textInputControlTransform
  }
  
  func updatePlaceholderScaleAndPosition(isTop: Bool) {
    let scale: CGFloat = isTop ? .placeholderScale : 1
    let transform = isTop ? CGAffineTransform(scaleX: .placeholderScale, y: .placeholderScale) : .identity
    placeholderLabel.transform = transform
    let horizontalSpace = bounds.width - padding.left - padding.right
    let sizeThatFits = placeholderLabel.sizeThatFits(CGSize(width: horizontalSpace, height: 0))
    let size = CGSize(width: min(horizontalSpace, sizeThatFits.width), height: sizeThatFits.height)
    let y: CGFloat = isTop ? 12 : padding.top
    let frame = CGRect(
      x: padding.left,
      y: y,
      width: size.width * scale,
      height: size.height * scale
    )
    placeholderLabel.frame = frame
  }
  
  func clearButtonAction() {
    inputText = ""
    didUpdateText?(inputText)
    updateTextAction()
  }
  
  func updateTextAction() {
    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
      self.updateClearButtonVisibility()
      self.updateTextInputAndPlaceholderLayoutAndScale()
    }
  }
  
  func didUpdateState() {
    textInputControl.textFieldState = textFieldState
  }
  
  func didSetClearButtonMode() {
    updateClearButtonVisibility()
  }
}

private extension CGFloat {
  static let placeholderScale: CGFloat = 0.75
  static let placeholderTopMargin: CGFloat = 12
  static let inputControlYOffset: CGFloat = 8
}
