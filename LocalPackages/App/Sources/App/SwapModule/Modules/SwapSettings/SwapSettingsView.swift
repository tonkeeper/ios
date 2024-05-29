import UIKit
import TKUIKit
import TKLocalize

final class SwapSettingsView: UIView {
  private let slippageTitleLabel = {
    let lbl = UILabel()
    lbl.text = TKLocales.SwapSettings.slippage
    lbl.font = TKTextStyle.label1.font
    lbl.textColor = .Text.primary
    return lbl
  }()
  
  private let slippageDescriptionLabel = {
    let lbl = UILabel()
    lbl.text = TKLocales.SwapSettings.description
    lbl.font = TKTextStyle.body3.font
    lbl.textColor = .Text.secondary
    lbl.numberOfLines = 0
    return lbl
  }()
  
  lazy var slippageAmountTextField: TKTextField = {
    let textInputControl = TKTextInputTextFieldControl()
    textInputControl.keyboardType = .decimalPad
    textInputControl.font = TKTextStyle.num2.font
    textInputControl.textAlignment = .left
    textInputControl.placeholder = "0"
    let percentageLabel = UILabel()
    percentageLabel.text = "%"
    percentageLabel.textColor = .Text.secondary
    percentageLabel.sizeToFit()
    textInputControl.rightView = percentageLabel
    textInputControl.rightViewMode = .always
    let tf = TKTextField(
      textFieldInputView: TKTextFieldInputView(
        textInputControl: textInputControl
      )
    )
    tf.didUpdateText = { [weak self] (text: String?) in
      self?.validateSlippageAmount()
    }
    return tf
  }()
  private func validateSlippageAmount() {
    guard let text = slippageAmountTextField.text, let value = Double(text) else {
      saveButton.isEnabled = false
      return
    }
    
    let maxValue = expertModeSwitch.isOn ? 100.0 : 50.0
    saveButton.configuration.isEnabled = (value > 0 && value < maxValue)
  }
  
  private func percentButton(percent: Int) -> TKButton {
    let btn = TKButton(configuration: .titleHeaderButtonConfiguration(category: .secondary))
    btn.configuration.padding = .zero
    btn.configuration.contentPadding.top = 16
    btn.configuration.contentPadding.bottom = 16
    btn.configuration.content = TKButton.Configuration.Content(
      title: .plainString("\(percent)%")
    )
    btn.tag = percent * 100
    btn.configuration.action = { [weak self] in
      guard let self else {return}
      for b in self.slippageSuggestionsView.arrangedSubviews {
        if let b = b as? TKButton {
          b.isSelected = false
        }
      }
      slippageAmountTextField.text = "\(percent)"
      btn.isSelected = true
    }
    return btn
  }

  lazy var slippageSuggestionsView = {
    let stackView = UIStackView()
    stackView.distribution = .fillEqually
    stackView.alignment = .fill
    stackView.spacing = 12
    stackView.addArrangedSubview(percentButton(percent: 1))
    stackView.addArrangedSubview(percentButton(percent: 3))
    stackView.addArrangedSubview(percentButton(percent: 5))
    return stackView
  }()
  
  private var expertModeLabels = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    let titleLabel = UILabel()
    titleLabel.text = TKLocales.SwapSettings.expertMode
    titleLabel.font = TKTextStyle.label1.font
    titleLabel.textColor = .Text.primary
    stackView.addArrangedSubview(titleLabel)

    titleLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
    titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

    let subtitleLabel = UILabel()
    subtitleLabel.text = TKLocales.SwapSettings.expertModeSettings
    subtitleLabel.font = TKTextStyle.body3.font
    subtitleLabel.textColor = .Text.secondary
    subtitleLabel.numberOfLines = 0
    stackView.addArrangedSubview(subtitleLabel)

    subtitleLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
    subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    
    return stackView
  }()

  lazy var expertModeSwitch = {
    let s = UISwitch()
    s.addTarget(self, action: #selector(expertModeChanged), for: .valueChanged)
    return s
  }()

  private lazy var expertModeView = {
    let stackView = UIStackView()
    stackView.alignment = .center
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.layoutMargins = .init(top: 16, left: 16, bottom: 16, right: 16)
    stackView.backgroundColor = .Field.background
    stackView.addArrangedSubview(expertModeLabels)
    stackView.addArrangedSubview(expertModeSwitch)
    stackView.layer.cornerRadius = 16
    return stackView
  }()

  let saveButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  
  private lazy var stackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.addArrangedSubview(slippageTitleLabel)
    stackView.addArrangedSubview(slippageDescriptionLabel)
    stackView.setCustomSpacing(12, after: slippageDescriptionLabel)
    stackView.addArrangedSubview(slippageAmountTextField)
    stackView.setCustomSpacing(12, after: slippageAmountTextField)
    stackView.addArrangedSubview(slippageSuggestionsView)
    stackView.setCustomSpacing(32, after: slippageSuggestionsView)
    stackView.addArrangedSubview(expertModeView)
    stackView.setCustomSpacing(24, after: expertModeView)
    saveButton.configuration.content.title = .plainString(TKLocales.Actions.save)
    stackView.addArrangedSubview(saveButton)
    return stackView
  }()
  
  var scrollView = UIScrollView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  @objc func expertModeChanged() {
    validateSlippageAmount()
  }
}

private extension SwapSettingsView {
  func setup() {
    backgroundColor = .Background.page
    addSubview(scrollView)
    scrollView.addSubview(stackView)
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 0),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor, constant: 0),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor, constant: 0)
    ])

    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
      stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
      stackView.leftAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leftAnchor, constant: 16),
      stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
      stackView.rightAnchor.constraint(equalTo: scrollView.contentLayoutGuide.rightAnchor, constant: -16)
    ])
  }
}
