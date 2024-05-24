import UIKit
import TKUIKit
import TKLocalize
import TKCore
import KeeperCore

final class SwapItemsViewController: GenericViewViewController<SwapItemsView>, KeyboardObserving {
  private let viewModel: SwapItemsViewModel
  
  init(viewModel: SwapItemsViewModel) {
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
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
  }

  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration,
    let keyboardHeight = notification.keyboardSize?.height else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.scrollView.contentInset.bottom = keyboardHeight
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.scrollView.contentInset.bottom = 0
    }
  }
}

private extension SwapItemsViewController {
  func setup() {
    title = TKLocales.Swap.title
    view.backgroundColor = .Background.page
    customView.scrollView.alpha = 0

    let settingsButton = TKUIHeaderIconButton()
    settingsButton.configure(
      model: TKUIHeaderButtonIconContentView.Model(
        image: .TKUIKit.Icons.Size16.settings
      )
    )

    settingsButton.addTapAction {
      self.viewModel.didTapSettings()
    }
    settingsButton.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: settingsButton)
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let customView = self?.customView else { return }
      let sellingAsset = model.sellItem.swapItem == nil ? nil : (model.sellItem.swapItem?.contractAddress == nil ? Asset.toncoin : model.assets?.first(where: { a in
        return a.contractAddress == model.sellItem.swapItem?.contractAddress
      }))
      let sellingAssetImage: TKSwapTokenFieldTokenView.Image
      switch sellingAsset?.contractAddress {
      case nil:
        sellingAssetImage = .image(.TKCore.Icons.Size44.tonLogo)
        break
      default:
        sellingAssetImage = .asyncImage(ImageDownloadTask(closure: { [weak self] imageView, size, cornerRadius in
          self?.viewModel.imageLoader.loadImage(url: URL(string: sellingAsset?.imageUrl ?? ""),
                                                imageView: imageView,
                                                size: size,
                                                cornerRadius: cornerRadius)
        }))
        break
      }
      let sellingToken = sellingAsset != nil ? TKSwapTokenFieldState.Token(
        image: sellingAssetImage, name: sellingAsset?.symbol ?? "", balance: model.sellItem.balanceString
      ) : nil
      customView.sellItemField.swapTokenFieldState = TKSwapTokenFieldState(
        isSellingToken: true,
        title: model.sellItem.title,
        token: sellingToken,
        amount: model.sellItem.amountString
      )
      let buyingAsset = model.buyItem.swapItem == nil ? nil : (model.buyItem.swapItem?.contractAddress == nil ? Asset.toncoin : model.assets?.first(where: { a in
        return a.contractAddress == model.buyItem.swapItem?.contractAddress
      }))
      let buyingAssetImage: TKSwapTokenFieldTokenView.Image
      switch buyingAsset?.contractAddress {
      case nil:
        buyingAssetImage = .image(.TKCore.Icons.Size44.tonLogo)
        break
      default:
        buyingAssetImage = .asyncImage(ImageDownloadTask(closure: { [weak self] imageView, size, cornerRadius in
          self?.viewModel.imageLoader.loadImage(url: URL(string: buyingAsset?.imageUrl ?? ""),
                                                imageView: imageView,
                                                size: size,
                                                cornerRadius: cornerRadius)
        }))
        break
      }
      let buyingToken = buyingAsset != nil ? TKSwapTokenFieldState.Token(
        image: buyingAssetImage, name: buyingAsset?.symbol ?? "", balance: model.buyItem.balanceString
      ) : nil
      customView.buyItemField.swapTokenFieldState = TKSwapTokenFieldState(
        isSellingToken: false,
        title: model.buyItem.title,
        token: buyingToken,
        amount: model.buyItem.amountString
      )
      
      customView.continueButton.configuration.content = TKButton.Configuration.Content(title: .plainString(model.button.title))
      customView.continueButton.configuration.isEnabled = model.button.isEnabled
      customView.continueButton.configuration.showsLoader = model.button.isActivity
      customView.continueButton.configuration.action = model.button.action
      
      // swap info
      if !model.button.isActivity {
        UIView.animate(withDuration: 0.2) {
          if model.button.isEnabled {
            customView.swapInfoViewHeightConstraint.update(offset: customView.isSwapInfoExpanded ? 1000 : 36)
          } else {
            customView.swapInfoViewHeightConstraint.update(offset: 0)
          }
          customView.layoutIfNeeded()
        }
        let exchangeRate = model.estimate?.swapRate ?? ""
        customView.rateLabel.text = "1 \(model.sellItem.swapItem?.symbol ?? "") ≈ \(exchangeRate) \(model.buyItem.swapItem?.symbol ?? "")"
        let priceImpactPercent = (model.estimate?.priceImpact ?? 0) * 100
        customView.priceImpactLabel.text = "\(String(format: "%.2f", priceImpactPercent))%"
        customView.priceImpactLabel.textColor = priceImpactPercent < 1 ? .green : (priceImpactPercent < 5 ? .orange : .red)
        customView.rateLabel.textColor = priceImpactPercent < 1 ? .Text.secondary : (priceImpactPercent < 5 ? .orange : .red)
        customView.minimumReceivedLabel.text = model.minAskAmount
        customView.liquidityProviderFeeLabel.text = model.liquidityFee
        customView.blockchainFeeLabel.text = "0.08 - 0.25 TON"
        customView.routeLabel.text = "\(model.sellItem.swapItem?.symbol ?? "") » \(model.buyItem.swapItem?.symbol ?? "")"
        customView.providerLabel.text = "STON.fi"
      }

      if self?.customView.scrollView.alpha == 0, sellingAsset != nil {
        UIView.animate(withDuration: 0.2) {
          self?.customView.scrollView.alpha = 1
          self?.view.layoutIfNeeded()
        }
      }
    }
  }
  
  func setupViewEvents() {
    customView.sellItemField.onChooseTapped = { [weak self] in
      self?.customView.endEditing(true)
      self?.viewModel.didTapSellItemTokenPicker()
    }
    customView.buyItemField.onChooseTapped = { [weak self] in
      self?.customView.endEditing(true)
      self?.viewModel.didTapBuyItemTokenPicker()
    }
    customView.sellItemField.didUpdateAmount = { [weak viewModel] amount in
      viewModel?.didInputSellAmount(amount)
    }
    customView.buyItemField.didUpdateAmount = { [weak viewModel] amount in
      viewModel?.didInputBuyAmount(amount)
    }
    customView.switchButton.configuration.action = { [weak self] in
      self?.customView.endEditing(true)
      self?.viewModel.didTapReverse()
    }
    customView.sellItemField.onMaxTapped = { [weak self] in
      self?.customView.endEditing(true)
      self?.viewModel.didTapMax()
    }
  }
}
