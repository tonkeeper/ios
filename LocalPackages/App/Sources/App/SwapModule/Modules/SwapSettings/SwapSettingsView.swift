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
  
  private lazy var textInputControl: TKTextInputTextFieldControl = {
    let textInputControl = TKTextInputTextFieldControl()
    textInputControl.keyboardType = .decimalPad
    textInputControl.font = TKTextStyle.num2.font
    textInputControl.textAlignment = .left
    textInputControl.placeholder = ""
    return textInputControl
  }()
  lazy var slippageAmountTextField = TKTextField(
    textFieldInputView: TKTextFieldInputView(
      textInputControl: textInputControl
    )
  )
  
  private func percentButton(percent: Int) -> TKButton {
    let btn = TKButton(configuration: .titleHeaderButtonConfiguration(category: .secondary))
    btn.configuration.padding.top = 0
    btn.configuration.padding.bottom = 0
    btn.configuration.content = TKButton.Configuration.Content(
      title: .plainString("\(percent)%")
    )
    btn.tag = percent * 100
    btn.configuration.action = { [weak self] in
      guard let self else {return}
      for b in slippageSuggestionsView.arrangedSubviews {
        if let b = b as? TKButton {
          b.isSelected = false
        }
      }
      slippageAmountTextField.text = "\(percent)"
      btn.isSelected = true
    }
    return btn
  }

  var slippageSuggestionsView: UIStackView {
    let stackView = UIStackView()
    stackView.distribution = .fillEqually
    stackView.alignment = .fill
    stackView.spacing = 12
    stackView.addArrangedSubview(percentButton(percent: 1))
    stackView.addArrangedSubview(percentButton(percent: 3))
    stackView.addArrangedSubview(percentButton(percent: 5))
    NSLayoutConstraint.activate([
      stackView.heightAnchor.constraint(equalToConstant: 56)
    ])
    return stackView
  }
  
  private var expertModeLabels = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    let titleLabel = UILabel()
    titleLabel.text = TKLocales.SwapSettings.expertMode
    titleLabel.font = TKTextStyle.label1.font
    titleLabel.textColor = .Text.primary
    stackView.addArrangedSubview(titleLabel)
    let subtitleLabel = UILabel()
    subtitleLabel.text = TKLocales.SwapSettings.expertModeSettings
    subtitleLabel.font = TKTextStyle.body3.font
    subtitleLabel.textColor = .Text.secondary
    subtitleLabel.numberOfLines = 0
    stackView.addArrangedSubview(subtitleLabel)
    subtitleLabel.sizeToFit()
    return stackView
  }()

  lazy var exportModeSwitch = UISwitch()

  private lazy var expertModeView = {
    let stackView = UIStackView()
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.layoutMargins = .init(top: 16, left: 16, bottom: 16, right: 16)
    stackView.backgroundColor = .Field.background
    stackView.addArrangedSubview(expertModeLabels)
    stackView.addArrangedSubview(exportModeSwitch)
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
