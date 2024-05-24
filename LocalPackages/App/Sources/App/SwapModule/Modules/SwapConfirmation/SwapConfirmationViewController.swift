import UIKit
import TKUIKit
import TKLocalize
import TKCore
import KeeperCore

final class SwapConfirmationViewController: GenericViewViewController<SwapConfirmationView> {
  private let viewModel: SwapConfirmationViewModel
  
  init(viewModel: SwapConfirmationViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBindings()
    setupViewEvents()
    viewModel.viewDidLoad()
  }
}

private extension SwapConfirmationViewController {
  func setup() {
    setupRightCloseButton { [weak self] in
      self?.dismiss(animated: true)
    }
    title = TKLocales.SwapConfirmation.title
    view.backgroundColor = .Background.page
    navigationItem.hidesBackButton = true

    let titleLabel = UILabel()
    titleLabel.attributedText = NSAttributedString(string: title!,
                                                   attributes: [.foregroundColor: UIColor.Text.primary,
                                                                .font: TKTextStyle.h3.font])
    titleLabel.sizeToFit()
    titleLabel.textAlignment = .left
    let titleView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
    titleLabel.frame = CGRect(x: 0, y: 0, width: titleLabel.bounds.width, height: 44)
    titleView.addSubview(titleLabel)
    navigationItem.titleView = titleView
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let customView = self?.customView else { return }
      let sellingAsset: Asset
      switch model.sellItem.swapItem.token {
      case .ton:
        sellingAsset = .toncoin
      case .jetton(let asset):
        sellingAsset = asset
      }
      let sellingAssetImage: TKSwapTokenFieldTokenView.Image
      switch sellingAsset.contractAddress {
      case nil:
        sellingAssetImage = .image(.TKCore.Icons.Size44.tonLogo)
        break
      default:
        sellingAssetImage = .asyncImage(ImageDownloadTask(closure: { [weak self] imageView, size, cornerRadius in
          self?.viewModel.imageLoader.loadImage(url: URL(string: sellingAsset.imageUrl),
                                                imageView: imageView,
                                                size: size,
                                                cornerRadius: cornerRadius)
        }))
        break
      }
      let sellingToken = TKSwapTokenFieldState.Token(
        image: sellingAssetImage, name: sellingAsset.symbol, balance: model.sellItem.amountInBaseCurrencyString
      )
      customView.sellItemField.swapTokenFieldState = TKSwapTokenFieldState(
        isSellingToken: true,
        previewMode: true,
        title: model.sellItem.title,
        token: sellingToken,
        amount: model.sellItem.amountString
      )
      let buyingAsset: Asset
      switch model.buyItem.swapItem.token {
      case .ton:
        buyingAsset = .toncoin
      case .jetton(let asset):
        buyingAsset = asset
      }
      let buyingAssetImage: TKSwapTokenFieldTokenView.Image
      switch buyingAsset.contractAddress {
      case nil:
        buyingAssetImage = .image(.TKCore.Icons.Size44.tonLogo)
        break
      default:
        buyingAssetImage = .asyncImage(ImageDownloadTask(closure: { [weak self] imageView, size, cornerRadius in
          self?.viewModel.imageLoader.loadImage(url: URL(string: buyingAsset.imageUrl),
                                                imageView: imageView,
                                                size: size,
                                                cornerRadius: cornerRadius)
        }))
        break
      }
      let buyingToken = TKSwapTokenFieldState.Token(
        image: buyingAssetImage, name: buyingAsset.symbol, balance: model.buyItem.amountInBaseCurrencyString
      )
      customView.buyItemField.swapTokenFieldState = TKSwapTokenFieldState(
        isSellingToken: false,
        previewMode: true,
        title: model.buyItem.title,
        token: buyingToken,
        amount: model.buyItem.amountString
      )

      customView.cancelButton.configuration.content.title = .plainString(TKLocales.Actions.cancel)
      customView.cancelButton.configuration.action = { [weak self] in
        self?.navigationController?.popViewController(animated: true)
      }
      
      customView.continueButton.configuration.content.title = .plainString(TKLocales.SwapConfirmation.confirm)
      customView.continueButton.configuration.isEnabled = true
      customView.continueButton.configuration.showsLoader = model.button.isActivity
      customView.continueButton.configuration.action = model.button.action
      
      // swap info
      let priceImpactPercent = (model.estimate?.priceImpact ?? 0) * 100
      customView.priceImpactLabel.text = "\(String(format: "%.2f", priceImpactPercent))%"
      customView.priceImpactLabel.textColor = priceImpactPercent < 1 ? .green : (priceImpactPercent < 5 ? .orange : .red)
      customView.minimumReceivedLabel.text = model.minAskAmount
      customView.liquidityProviderFeeLabel.text = model.liquidityFee
      customView.blockchainFeeLabel.text = "0.08 - 0.25 TON"
      customView.routeLabel.text = "\(model.sellItem.swapItem.symbol) » \(model.buyItem.swapItem.symbol)"
      customView.providerLabel.text = "STON.fi"
    }
  }
  
  func setupViewEvents() {
  }
}
