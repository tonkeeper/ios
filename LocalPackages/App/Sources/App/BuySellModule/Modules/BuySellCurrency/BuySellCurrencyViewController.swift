import UIKit
import TKCore
import TKUIKit
import KeeperCore

typealias CurrencySelectionCallback = (FiatMethodLayout) -> Void

class BuySellCurrencyViewController: UIViewController {
  var onCurrencySelected: CurrencySelectionCallback?
  var currencies: [FiatMethodLayout]

  init(currencies: [FiatMethodLayout]) {
    self.currencies = currencies
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private var selectedIndex: IndexPath?
  private let tableView = UITableView()
  
  override func viewDidLoad() {
      super.viewDidLoad()
      setupTableView()
  }
  
  private func setupTableView() {
      tableView.frame = view.bounds
      tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      tableView.register(CurrencyCell.self, forCellReuseIdentifier: "CurrencyCell")
      tableView.dataSource = self
      tableView.delegate = self
      view.addSubview(tableView)
  }
}

extension BuySellCurrencyViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return currencies.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "CurrencyCell", for: indexPath) as? CurrencyCell else {
      return UITableViewCell()
    }
    let currency = currencies[indexPath.row]
    cell.configure(with: currency)
    cell.accessoryType = (selectedIndex == indexPath) ? .checkmark : .none
    return cell
  }
}

extension BuySellCurrencyViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let selectedCurrency = currencies[indexPath.row]
    
    if let previousIndex = selectedIndex {
        tableView.cellForRow(at: previousIndex)?.accessoryType = .none
    }
    selectedIndex = indexPath
    tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    
    onCurrencySelected?(selectedCurrency)
    tableView.deselectRow(at: indexPath, animated: true)
  }
}

private class CurrencyCell: UITableViewCell {
  
  private let codeLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.label1.font
    label.textColor = .Text.primary
    return label
  }()

  private let nameLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.body1.font
    label.textColor = .Text.secondary
    return label
  }()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupViews()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupViews() {
    let stackView = UIStackView(arrangedSubviews: [codeLabel, nameLabel])
    stackView.axis = .horizontal
    stackView.spacing = 8
    stackView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stackView)
    
    NSLayoutConstraint.activate([
      stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
    ])
  }
  
  func configure(with currency: FiatMethodLayout) {
    codeLabel.text = currency.countryCode
    nameLabel.text = currency.currency
  }
}
