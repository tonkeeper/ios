import UIKit
import TKUIKit
import SnapKit
import TKLocalize

final class BuySellAmountView: UIView {
  
  let container = UIView()
  let amountInputContainer = UIView()
  var onModeChanged: (() -> Void)?
  
  let creditCardRow = {
    let stackView = UIStackView()
    stackView.distribution = .fill
    stackView.alignment = .center
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.layoutMargins = .init(top: 0, left: 16, bottom: 0, right: 16)
    stackView.spacing = 4
    let checkBox = TKCheckBox()
    checkBox.snp.makeConstraints { make in
      make.width.height.equalTo(24)
    }
    stackView.addArrangedSubview(checkBox)
    let label = UILabel()
    label.font = TKTextStyle.label1.font
    label.text = TKLocales.BuySell.creditCard
    label.textColor = .Text.primary
    stackView.addArrangedSubview(label)
    stackView.addArrangedSubview(UIImageView(image: .TKUIKit.Images.BuySell.credit1))
    stackView.addArrangedSubview(UIImageView(image: .TKUIKit.Images.BuySell.credit2))
    stackView.layer.cornerRadius = 12
    stackView.backgroundColor = .Background.content
    stackView.snp.makeConstraints { make in
      make.height.equalTo(56)
    }
    return stackView
  }()
  
  lazy var bottomStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .fill
    stackView.spacing = 16
    stackView.addArrangedSubview(creditCardRow)
    continueButton.configuration.content.title = .plainString(TKLocales.Actions.continue_action)
    stackView.addArrangedSubview(continueButton)
    return stackView
  }()
  
  var isBuying = true {
    didSet {
      onModeChanged?()
    }
  }
  var buyButton: TKButton!
  var sellButton: TKButton!
  var selectedBuyItemLine: UIView!
  var selectedSellItemLine: UIView!
  lazy var titleView = {
    let titleView = UIView()

    buyButton = TKButton(configuration: .accentButtonConfiguration(padding: .zero))
    buyButton.configuration.content.title = .plainString("Buy")
    buyButton.configuration.textColor = .Text.primary
    buyButton.configuration.action = { [weak self] in
      guard let self else {return}
      selectedBuyItemLine.alpha = 1
      selectedSellItemLine.alpha = 0
      buyButton.configuration.textColor = .Text.primary
      sellButton.configuration.textColor = .Text.secondary
      isBuying = true
    }

    sellButton = TKButton(configuration: .accentButtonConfiguration(padding: .zero))
    sellButton.configuration.content.title = .plainString("Sell")
    sellButton.configuration.textColor = .Text.secondary
    sellButton.configuration.action = { [weak self] in
      guard let self else {return}
      selectedBuyItemLine.alpha = 0
      selectedSellItemLine.alpha = 1
      buyButton.configuration.textColor = .Text.secondary
      sellButton.configuration.textColor = .Text.primary
      isBuying = false
    }
    
    selectedBuyItemLine = UIView()
    selectedBuyItemLine.translatesAutoresizingMaskIntoConstraints = false
    selectedBuyItemLine.backgroundColor = .Button.primaryBackground

    selectedSellItemLine = UIView()
    selectedSellItemLine.translatesAutoresizingMaskIntoConstraints = false
    selectedSellItemLine.backgroundColor = .Button.primaryBackground
    selectedSellItemLine.alpha = 0

    titleView.addSubview(buyButton)
    titleView.addSubview(sellButton)
    titleView.addSubview(selectedBuyItemLine)
    titleView.addSubview(selectedSellItemLine)

    buyButton.translatesAutoresizingMaskIntoConstraints = false
    sellButton.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      titleView.heightAnchor.constraint(equalToConstant: 37),
      
      buyButton.leadingAnchor.constraint(equalTo: titleView.leadingAnchor),
      buyButton.topAnchor.constraint(equalTo: titleView.topAnchor),
      buyButton.bottomAnchor.constraint(equalTo: titleView.bottomAnchor),

      sellButton.leadingAnchor.constraint(equalTo: buyButton.trailingAnchor, constant: 12),
      sellButton.trailingAnchor.constraint(equalTo: titleView.trailingAnchor),
      sellButton.topAnchor.constraint(equalTo: titleView.topAnchor),
      sellButton.bottomAnchor.constraint(equalTo: titleView.bottomAnchor),
      
      selectedBuyItemLine.leadingAnchor.constraint(equalTo: buyButton.leadingAnchor),
      selectedBuyItemLine.trailingAnchor.constraint(equalTo: buyButton.trailingAnchor),
      selectedBuyItemLine.bottomAnchor.constraint(equalTo: titleView.bottomAnchor),
      selectedBuyItemLine.heightAnchor.constraint(equalToConstant: 3),

      selectedSellItemLine.leadingAnchor.constraint(equalTo: sellButton.leadingAnchor),
      selectedSellItemLine.trailingAnchor.constraint(equalTo: sellButton.trailingAnchor),
      selectedSellItemLine.bottomAnchor.constraint(equalTo: titleView.bottomAnchor),
      selectedSellItemLine.heightAnchor.constraint(equalToConstant: 3)
    ])
    return titleView
  }()
  
  let currencyButton = {
    let btn = TKButton(configuration: .actionButtonConfiguration(category: .secondary, size: .small))
    btn.configuration.content.title = .plainString("RU")
    btn.snp.makeConstraints { make in
      make.width.equalTo(80)
    }
    return btn
  }()
  
  let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func embedAmountInputView(_ view: UIView) {
    amountInputContainer.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(amountInputContainer)
    }
  }
}

private extension BuySellAmountView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(container)
    container.addSubview(amountInputContainer)
    container.addSubview(bottomStackView)

    setupConstraints()
  }
  
  func setupConstraints() {
    container.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide).inset(16)
      make.left.right.equalTo(self)
    }
    
    amountInputContainer.snp.makeConstraints { make in
      make.left.right.equalTo(container).inset(16)
      make.height.equalTo(210)
      make.top.equalTo(container)
    }
    
    bottomStackView.snp.makeConstraints { make in
      make.top.equalTo(amountInputContainer.snp.bottom).offset(12)
      make.left.right.equalTo(container).inset(16)
      make.bottom.equalTo(container).inset(16)
    }
  }
}
