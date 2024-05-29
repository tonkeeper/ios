import UIKit
import TKCore
import TKUIKit
import TKLocalize
import TKScreenKit
import KeeperCore

class BuySellConfirmViewController: UIViewController {
  let fiatMethods: FiatMethods
  let operatorObj: BuySellItemModel
  let rate: BuySellRateItem?
  let selectedCurrency: String
  let amount: Double
  let isBuying: Bool
  
  var showingOperators = [BuySellItemModel]()

  init(fiatMethods: FiatMethods,
       operatorObj: BuySellItemModel,
       selectedCurrency: String,
       rate: BuySellRateItem?,
       amount: Double,
       isBuying: Bool) {
    self.fiatMethods = fiatMethods
    self.operatorObj = operatorObj
    self.selectedCurrency = selectedCurrency
    self.rate = rate
    self.amount = amount
    self.isBuying = isBuying
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  
  override func viewDidLoad() {
    super.viewDidLoad()

    title = "Operator"
    view.backgroundColor = .Background.page

    setupViews()
  }
  
  private func setupViews() {
    setupRightCloseButton { [weak self] in
      self?.dismiss(animated: true)
    }
    let backButton = TKUIHeaderIconButton()
    backButton.configure(
      model: TKUIHeaderButtonIconContentView.Model(
        image: .TKUIKit.Icons.Size16.chevronLeft
      )
    )
    backButton.addTapAction {
      self.navigationController?.popViewController(animated: true)
    }
    backButton.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)

    let scrollView = UIScrollView()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.keyboardDismissMode = .onDrag
    view.addSubview(scrollView)
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(view.safeAreaLayoutGuide)
    }
    scrollView.contentLayoutGuide.snp.makeConstraints { make in
      make.width.equalTo(view)
    }

    let topImageView = UIImageView()
    topImageView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(topImageView)
    topImageView.snp.makeConstraints { make in
      make.top.equalTo(scrollView.contentLayoutGuide.snp.top).offset(12)
      make.centerX.equalTo(scrollView.contentLayoutGuide.snp.centerX)
      make.width.height.equalTo(72)
    }
    topImageView.layer.cornerRadius = 12
    topImageView.layer.masksToBounds = true
    topImageView.kf.setImage(with: operatorObj.iconURL)
    
    let titleLabel = UILabel()
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(titleLabel)
    titleLabel.font = TKTextStyle.h2.font
    titleLabel.text = operatorObj.title
    titleLabel.textColor = .Text.primary
    titleLabel.snp.makeConstraints { make in
      make.top.equalTo(topImageView.snp.bottom).offset(12)
      make.centerX.equalTo(scrollView.contentLayoutGuide.snp.centerX)
    }
    
    let subtitleLabel = UILabel()
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(subtitleLabel)
    subtitleLabel.font = TKTextStyle.body0.font
    subtitleLabel.text = operatorObj.title
    subtitleLabel.textColor = .Text.secondary
    subtitleLabel.snp.makeConstraints { make in
      make.top.equalTo(titleLabel.snp.bottom).offset(4)
      make.centerX.equalTo(scrollView.contentLayoutGuide.snp.centerX)
    }
    subtitleLabel.text = isBuying ? TKLocales.BuySell.instantBuy : TKLocales.BuySell.instantSell
    
    let youPayTextField = TKTextField(
      textFieldInputView: TKTextFieldInputView(
        textInputControl: TKTextInputTextViewControl()
      )
    )
    let youGetTextField = TKTextField(
      textFieldInputView: TKTextFieldInputView(
        textInputControl: TKTextInputTextViewControl()
      )
    )
    if let rate {
      let lblYouPay = UILabel()
      lblYouPay.textColor = .Text.secondary
      lblYouPay.font = TKTextStyle.body1.font
      lblYouPay.text = isBuying ? "\(rate.currency)   " : "TON   "
      youPayTextField.rightItems = [.init(view: lblYouPay, mode: .always)]
      youPayTextField.placeholder = TKLocales.BuySell.youPay
      scrollView.addSubview(youPayTextField)
      youPayTextField.snp.makeConstraints { make in
        make.top.equalTo(subtitleLabel.snp.bottom).offset(32)
        make.left.right.equalTo(scrollView.contentLayoutGuide).inset(16)
      }
      youPayTextField.text = numberFormatter.string(from: rate.rate * amount as NSNumber)
      youPayTextField.didUpdateText = { [weak self] text in
        guard let self else {return}
        if let amount = Double(sendAmountTextFieldFormatter.unformatString(text) ?? "") {
          youPayTextField.text = numberFormatter.string(from: amount as NSNumber)
          youGetTextField.text = numberFormatter.string(from: amount / rate.rate as NSNumber)
        }
      }
    }
    
    let rateLabel = UILabel()
    let lblYouGet = UILabel()
    lblYouGet.textColor = .Text.secondary
    lblYouGet.font = TKTextStyle.body1.font
    lblYouGet.text = isBuying ? "TON   " : "\(rate?.currency ?? selectedCurrency)   "
    youGetTextField.rightItems = [.init(view: lblYouGet, mode: .always)]
    youGetTextField.placeholder = TKLocales.BuySell.youGet
    scrollView.addSubview(youGetTextField)
    youGetTextField.snp.makeConstraints { make in
      make.top.equalTo(rate == nil ? subtitleLabel : youPayTextField.snp.bottom).offset(16 + (rate == nil ? 16 : 0))
      make.left.right.equalTo(scrollView.contentLayoutGuide).inset(16)
    }
    youGetTextField.text = numberFormatter.string(from: amount as NSNumber)
    youGetTextField.didUpdateText = { [weak self] text in
      guard let self else {return}
      guard let rate else {return}
      if let amount = Double(sendAmountTextFieldFormatter.unformatString(text) ?? "") {
        youGetTextField.text = numberFormatter.string(from: amount as NSNumber)
        youPayTextField.text = numberFormatter.string(from: rate.rate * amount as NSNumber)
      }
    }
    
    if let rate {
      rateLabel.translatesAutoresizingMaskIntoConstraints = false
      scrollView.addSubview(rateLabel)
      rateLabel.font = TKTextStyle.body2.font
      rateLabel.text = operatorObj.title
      rateLabel.textColor = .Text.secondary
      rateLabel.snp.makeConstraints { make in
        make.top.equalTo(youGetTextField.snp.bottom).offset(12)
        make.left.equalTo(view.snp.left).offset(32)
      }
      rateLabel.text = "\("\(rate.rate)".prefix(6)) \(rate.currency) for 1 TON"
    }
    
    scrollView.addSubview(continueButton)
    continueButton.configuration.content.title = .plainString(TKLocales.Actions.continue_action)
    continueButton.snp.makeConstraints { make in
      make.left.right.equalTo(scrollView.contentLayoutGuide).inset(16)
      make.top.equalTo(rate == nil ? youGetTextField.snp.bottom : rateLabel.snp.bottom).offset(16)
    }
    continueButton.configuration.action = { [weak self] in
      guard let self else {return}
      if let actionURL = operatorObj.actionURL {
        openWebView(url: actionURL, fromViewController: self)
      }
    }
    
    let serviceProviderLabel = UILabel()
    scrollView.addSubview(serviceProviderLabel)
    serviceProviderLabel.font = TKTextStyle.body2.font
    serviceProviderLabel.textColor = .Text.secondary
    serviceProviderLabel.text = "Service provided by \(operatorObj.title)"
    serviceProviderLabel.snp.makeConstraints { make in
      make.centerX.equalTo(scrollView.contentLayoutGuide.snp.centerX)
      make.top.equalTo(continueButton.snp.bottom).offset(16)
    }
    
    let urlsStackView = UIStackView()
    urlsStackView.alignment = .center
    urlsStackView.spacing = 4
    scrollView.addSubview(urlsStackView)
    var labels = [UILabel]()
    for (i, infoButton) in operatorObj.infoButtons.enumerated() {
      let itemLabel = UILabel()
      itemLabel.font = TKTextStyle.body2.font
      itemLabel.textColor = .Text.tertiary
      itemLabel.text = infoButton.title
      itemLabel.tag = i
      itemLabel.isUserInteractionEnabled = true
      itemLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(infoItemPressed)))
      labels.append(itemLabel)
    }
    addViewsWithDots(to: urlsStackView, views: labels)
    urlsStackView.snp.makeConstraints { make in
      make.centerX.equalTo(scrollView.contentLayoutGuide.snp.centerX)
      make.top.equalTo(serviceProviderLabel.snp.bottom).offset(4)
      make.bottom.equalTo(scrollView.contentLayoutGuide).offset(16)
    }
  }
  
  func createDotView() -> UIView {
    let dotView = UIView()
    dotView.translatesAutoresizingMaskIntoConstraints = false
    dotView.backgroundColor = .Text.secondary
    dotView.layer.cornerRadius = 2
    dotView.widthAnchor.constraint(equalToConstant: 4).isActive = true
    dotView.heightAnchor.constraint(equalToConstant: 4).isActive = true
    return dotView
  }
  func addViewsWithDots(to stackView: UIStackView, views: [UIView]) {
    for (index, view) in views.enumerated() {
      stackView.addArrangedSubview(view)
      if index < views.count - 1 {
        stackView.addArrangedSubview(createDotView())
      }
    }
  }
  
  @objc func infoItemPressed(sender: UIGestureRecognizer) {
    guard let url = URL(string: operatorObj.infoButtons[sender.view?.tag ?? 0].url ?? "") else {
      return
    }
    openWebView(url: url, fromViewController: self)
  }
  
  private var numberFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.groupingSeparator = " "
    formatter.groupingSize = 3
    formatter.usesGroupingSeparator = true
    formatter.decimalSeparator = Locale.current.decimalSeparator
    formatter.maximumFractionDigits = 4
    return formatter
  }
  
  private func openWebView(url: URL, fromViewController: UIViewController) {
    let webViewController = TKWebViewController(url: url)
    let navigationController = UINavigationController(rootViewController: webViewController)
    navigationController.modalPresentationStyle = .fullScreen
    navigationController.configureTransparentAppearance()
    fromViewController.present(navigationController, animated: true)
  }
  
  private let sendAmountTextFieldFormatter: SendAmountTextFieldFormatter = {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSeparator = " "
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumIntegerDigits = 16
    numberFormatter.roundingMode = .down
    let amountInputFormatController = SendAmountTextFieldFormatter(
      currencyFormatter: numberFormatter
    )
    return amountInputFormatController
  }()
  
}
