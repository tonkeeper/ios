import UIKit
import TKCore
import TKUIKit
import TKLocalize
import KeeperCore

class BuySellOperatorViewController: UIViewController {
  let fiatMethods: FiatMethods
  let operators: [BuySellItemModel]
  let selectedCurrency: String
  let rates: BuySellRateItemsResponse
  let amount: Double
  let isBuying: Bool
  
  var showingOperators = [BuySellItemModel]()

  init(fiatMethods: FiatMethods,
       operators: [BuySellItemModel],
       selectedCurrency: String,
       rates: BuySellRateItemsResponse,
       amount: Double,
       isBuying: Bool) {
    self.fiatMethods = fiatMethods
    self.operators = operators
    self.showingOperators = operators
    self.selectedCurrency = selectedCurrency
    self.rates = rates
    self.amount = amount
    self.isBuying = isBuying
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private var selectedIndex: IndexPath?
  private let tableView = UITableView()
  
  private let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  
  var bestRate: Double?
  override func viewDidLoad() {
    super.viewDidLoad()

    // find min amount (best rate)
    bestRate = showingOperators.filter({ it in
      rates.items.contains { i in
        it.id == i.id
      }
    }).map({ it in
      return rates.items.first { i in
        it.id == i.id
      }!
    }).map { it in
      return it.rate
    }.min()
    // find best index
    if let bestRate {
      self.selectedIndex = IndexPath(item: showingOperators.firstIndex(where: { it in
        let r = rates.items.first { i in
          it.id == i.id
        }
        guard let r else {return false}
        return r.rate == bestRate
      }) ?? 0, section: 0)
    }
    
    title = "Operator"
    view.backgroundColor = .Background.page

    setupTableView()
    
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
  }
  
  private func setupTableView() {
    tableView.register(OperatorCell.self, forCellReuseIdentifier: "OperatorCell")
    tableView.dataSource = self
    tableView.delegate = self
    tableView.separatorColor = .clear
    tableView.backgroundColor = .Background.page
    tableView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(tableView)
    tableView.snp.makeConstraints { make in
      make.top.left.right.equalTo(view)
    }
    view.addSubview(continueButton)
    continueButton.configuration.isEnabled = selectedIndex != nil
    continueButton.configuration.content.title = .plainString(TKLocales.Actions.continue_action)
    continueButton.configuration.action = { [weak self] in
      guard let self else {return}
      let confirmVC = BuySellConfirmViewController(fiatMethods: fiatMethods,
                                                   operatorObj: showingOperators[selectedIndex?.row ?? 0],
                                                   selectedCurrency: selectedCurrency,
                                                   rate: rates.items.first(where: { it in
        it.id == self.showingOperators[self.selectedIndex?.row ?? 0].id
      }), amount: amount, isBuying: isBuying)
      navigationController?.pushViewController(confirmVC, animated: true)
    }
    continueButton.snp.makeConstraints { make in
      make.left.right.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
      make.top.equalTo(tableView.snp.bottom).inset(16)
    }
  }
}

extension BuySellOperatorViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return showingOperators.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "OperatorCell", for: indexPath) as? OperatorCell else {
      return UITableViewCell()
    }
    let operatorObj = showingOperators[indexPath.row]
    cell.selectionStyle = .none
    let rate = rates.items.first(where: { it in
      it.id == operatorObj.id
    })
    cell.configure(with: operatorObj,
                   position: indexPath.row == 0 ? .top : (indexPath.row == showingOperators.count - 1 ? .bottom : .middle),
                   isSelected: selectedIndex == indexPath,
                   rate: rate,
                   isBest: rate != nil && rate?.rate == bestRate)
    return cell
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 76
  }
}

extension BuySellOperatorViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    selectedIndex = indexPath
    continueButton.configuration.isEnabled = true
    tableView.reloadData()
  }
}

private class OperatorCell: UITableViewCell {
  
  private let operatorImage: UIImageView = {
    let img = UIImageView()
    img.snp.makeConstraints { make in
      make.width.height.equalTo(44)
    }
    img.layer.masksToBounds = true
    img.layer.cornerRadius = 12
    return img
  }()

  private let nameLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.label1.font
    label.textColor = .Text.primary
    return label
  }()
  
  private let bestLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.label4.font
    label.backgroundColor = .Button.tertiaryBackground
    label.textColor = .Button.primaryBackground
    label.layer.cornerRadius = 4
    label.layer.masksToBounds = true
    label.snp.makeConstraints { make in
      make.height.equalTo(20)
    }
    label.text = " BEST "
    return label
  }()
  
  private lazy var nameAndBestView: UIStackView = {
    let stackView = UIStackView()
    stackView.alignment = .center
    stackView.spacing = 6
    stackView.addArrangedSubview(nameLabel)
    stackView.addArrangedSubview(bestLabel)
    return stackView
  }()

  private let rateLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.body1.font
    label.textColor = .Text.secondary
    return label
  }()
  
  private lazy var nameAndRateView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .leading
    stackView.addArrangedSubview(nameAndBestView)
    stackView.addArrangedSubview(rateLabel)
    return stackView
  }()
  
  private let checkBox: TKCheckBox = {
    let checkBox = TKCheckBox()
    checkBox.snp.makeConstraints { make in
      make.width.height.equalTo(24)
    }
    return checkBox
  }()
  
  enum Position {
    case top
    case middle
    case bottom
  }
  
  private var stackView: UIStackView!
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupViews()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupViews() {
    stackView = UIStackView(arrangedSubviews: [operatorImage, nameAndRateView, checkBox])
    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.distribution = .fill
    stackView.spacing = 8
    stackView.backgroundColor = .Background.content
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.layer.cornerRadius = 12
    stackView.layoutMargins = .init(top: 0, left: 16, bottom: 0, right: 16)
    stackView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stackView)
    contentView.backgroundColor = .Background.page
    
    NSLayoutConstraint.activate([
      stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
      stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    ])
  }
  
  func configure(with operatorObj: BuySellItemModel,
                 position: Position,
                 isSelected: Bool,
                 rate: BuySellRateItem?,
                 isBest: Bool) {
    nameLabel.text = operatorObj.title
    if let rate {
      rateLabel.text = "\("\(rate.rate)".prefix(6)) \(rate.currency) for 1 TON"
    } else {
      rateLabel.text = ""
    }
    if let url = operatorObj.iconURL {
      operatorImage.kf.setImage(with: url)
    } else {
      operatorImage.image = nil
    }
    switch position {
    case .top:
      stackView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    case .middle:
      stackView.layer.maskedCorners = []
    case .bottom:
      stackView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    }
    checkBox.isChecked = isSelected
    bestLabel.isHidden = !isBest
  }
}
