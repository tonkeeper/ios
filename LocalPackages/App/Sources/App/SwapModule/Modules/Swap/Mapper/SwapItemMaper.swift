import UIKit
import KeeperCore
import TKCore

struct SwapItemMaper {
  
  let imageLoader = ImageLoader()
  
  func mapAmountHeader(title: String,
                       balanceTitle: String?,
                       maxButton: SwapAmountHeaderView.Model.Button? = nil) -> SwapAmountHeaderView.Model {
    SwapAmountHeaderView.Model(
      leftTitle: title.withTextStyle(.body2, color: .Text.secondary, alignment: .left),
      rightTitle: balanceTitle?.withTextStyle(.body2, color: .Text.secondary, alignment: .right),
      button: maxButton
    )
  }
  
  func mapTokenButton(buttonToken: SwapToken?, action: (() -> Void)?) -> SwapInputContainerView.Model.TokenButton {
    if let buttonToken {
      return SwapInputContainerView.Model.TokenButton(
        title: buttonToken.asset.symbol,
        icon: mapSwapTokenIcon(buttonToken.icon),
        action: action
      )
    } else {
      return SwapInputContainerView.Model.TokenButton(
        title: "CHOOSE",
        icon: .image(nil),
        action: action
      )
    }
  }
  
  func mapSwapTokenIcon(_ icon: SwapToken.Icon) -> SwapTokenButton.Model.Icon {
    switch icon {
    case .image(let image):
      return .image(image)
    case .asyncImage(let imageUrl):
      let iconImageDownloadTask = configureDownloadTask(forUrl: imageUrl)
      return .asyncImage(iconImageDownloadTask)
    }
  }
  
  func mapSwapAsset(_ swapAsset: SwapAsset) -> SwapToken {
    let icon: SwapToken.Icon
    let isToncoin = swapAsset.kind == .ton && swapAsset.symbol == TonInfo.symbol
    if isToncoin {
      icon = .image(.TKCore.Icons.Size44.tonLogo)
    } else {
      icon = .asyncImage(swapAsset.imageUrl)
    }
    
    return SwapToken(
      icon: icon,
      asset: swapAsset,
      balance: .zero,
      inputAmount: "0"
    )
  }
  
  func mapSwapSimulationRate(swapRate: SwapSimulationModel.Rate, swapRoute: SwapSimulationModel.Info.Route) -> SwapRateRow.Model {
    SwapRateRow.Model(
      swapRate: swapRate.toString(route: swapRoute).withTextStyle(.body2, color: .Text.primary)
    )
  }
  
  func mapSwapSimulationInfo(_ swapSimulationInfo: SwapSimulationModel.Info) -> SwapInfoContainerView.Model {
    SwapInfoContainerView.Model(
      priceImpact: createSwapInfoRowModel(
        infoTitle: "Price impact",
        value: "\(swapSimulationInfo.priceImpact)%",
        infoButtonAction: {}
      ),
      minimumRecieved: createSwapInfoRowModel(
        infoTitle: "Minimum received",
        value: "\(swapSimulationInfo.minimumRecieved) \(swapSimulationInfo.route.tokenSymbolRecieve)",
        infoButtonAction: {}
      ),
      liquidityProviderFee: createSwapInfoRowModel(
        infoTitle: "Liquidity provider fee",
        value: "\(swapSimulationInfo.liquidityProviderFee) \(swapSimulationInfo.route.tokenSymbolRecieve)",
        infoButtonAction: {}
      ),
      blockchainFee: createSwapInfoRowModel(
        infoTitle: "Blockchain fee",
        value: swapSimulationInfo.blockchainFee
      ),
      route: createSwapInfoRowModel(
        infoTitle: "Route",
        value: swapSimulationInfo.route.toString()
      ),
      provider: createSwapInfoRowModel(
        infoTitle: "Provider",
        value: swapSimulationInfo.providerName
      )
    )
  }
  
  func createEnterAmountButton(isActivity: Bool) -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Enter Amount",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: !isActivity,
      isActivity: isActivity,
      action: nil
    )
  }
  
  func createChoseTokenButton(isActivity: Bool) -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Choose Token",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: !isActivity,
      isActivity: isActivity,
      action: nil
    )
  }
  
  func createInsufficientBalanceTonButton(isActivity: Bool, action: (() -> Void)?) -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Insufficient Balance. Buy TON",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: true,
      isActivity: isActivity,
      action: action
    )
  }
  
  func createInsufficientBalanceButton(tokenSymbol: String, isActivity: Bool) -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Insufficient \(tokenSymbol) balance",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: true,
      isActivity: isActivity,
      action: nil
    )
  }
  
  func createContinueButton(isEnabled: Bool, isActivity: Bool, action: (() -> Void)?) -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Continue",
      backgroundColor: .Button.primaryBackground,
      backgroundColorHighlighted: .Button.primaryBackgroundHighlighted,
      isEnabled: !isActivity && isEnabled,
      isActivity: isActivity,
      action: action
    )
  }
  
  func createSimulationFailButton() -> SwapActionButtonModel {
    SwapActionButtonModel(
      title: "Simulation fail",
      backgroundColor: .Button.secondaryBackground,
      backgroundColorHighlighted: .Button.secondaryBackgroundHighlighted,
      isEnabled: true,
      isActivity: false,
      action: nil
    )
  }
}

private extension SwapItemMaper {
  func configureDownloadTask(forUrl url: URL?) -> TKCore.ImageDownloadTask {
    TKCore.ImageDownloadTask { [imageLoader] imageView, size, cornerRadius in
      return imageLoader.loadImage(
        url: url,
        imageView: imageView,
        size: .iconSize,
        cornerRadius: .iconCornerRadius
      )
    }
  }
  
  func createSwapInfoRowModel(infoTitle: String, value: String, infoButtonAction: (() -> Void)? = nil) -> SwapInfoRow.Model {
    var infoButton: InfoLabel.Model.InfoButton?
    if let infoButtonAction {
      infoButton = .init(action: infoButtonAction)
    }
    return SwapInfoRow.Model(
      infoLabel: InfoLabel.Model(
        title: infoTitle.withTextStyle(.body2, color: .Text.secondary),
        infoButton: infoButton
      ),
      value: value.withTextStyle(.body2, color: .Text.primary, alignment: .right)
    )
  }
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
}

private extension CGFloat {
  static let iconCornerRadius: CGFloat = 22
}
