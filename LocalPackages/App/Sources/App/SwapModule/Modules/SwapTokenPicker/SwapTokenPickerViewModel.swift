import Foundation
import KeeperCore
import TKUIKit
import TKCore

protocol SwapTokenPickerModuleOutput: AnyObject {
  var didFinish: (() -> Void)? { get set }
  var didSelectToken: ((SwapToken) -> Void)? { get set }
}

protocol SwapTokenPickerViewModel: AnyObject {
  var didUpdateTokens: (([SwapTokenPickerCell.Model], [SwapTokenPickerSuggestedCell.Model]) -> Void)? { get set }
  var didUpdateSelectedToken: ((Int) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectItemAt(section: Int, index: Int)
  func update(searchText: String)
}

final class SwapTokenPickerViewModelImplementation: SwapTokenPickerViewModel, SwapTokenPickerModuleOutput {
  
  // MARK: - TokenPickerModuleOutput
  
  var didFinish: (() -> Void)?
  var didSelectToken: ((SwapToken) -> Void)?
  
  // MARK: - TokenPickerViewModel
  
  var didUpdateTokens: (([SwapTokenPickerCell.Model], [SwapTokenPickerSuggestedCell.Model]) -> Void)?
  var didUpdateSelectedToken: ((Int) -> Void)?
  
  func viewDidLoad() {
    setupControllerBindings()
    
    Task {
      await swapTokenPickerController.start()
    }
  }
  
  func didSelectItemAt(section: Int, index: Int) {
    switch section {
    case 0:
      didSelectToken?(swapTokenPickerController.getSuggestedTokenAt(index: index))
      didFinish?()
    default:
      if swapTokenPickerController.isTokenSelectedAt(index: index) {
        didFinish?()
      } else {
        didSelectToken?(swapTokenPickerController.getTokenAt(index: index))
        didFinish?()
      }
    }
  }
  
  func update(searchText: String) {
    Task {
      await swapTokenPickerController.search(text: searchText.lowercased())
    }
  }
  
  // MARK: - Image Loading
  
  private let imageLoader = ImageLoader()
  
  // MARK: - Dependencies
  
  private let swapTokenPickerController: SwapTokenPickerController
  
  // MARK: - Init
  
  init(swapTokenPickerController: SwapTokenPickerController) {
    self.swapTokenPickerController = swapTokenPickerController
  }
}

private extension SwapTokenPickerViewModelImplementation {
  func setupControllerBindings() {
    swapTokenPickerController.didUpdateTokens = { [weak self, imageLoader] suggestedTokens, tokens in
      guard let self = self else { return }
      let models = tokens.map { token in
        let image: TKListItemIconImageView.Model.Image
        switch token.image {
        case .ton:
          image = .image(.TKCore.Icons.Size44.tonLogo)
        case .url(let url):
          image = .asyncImage(TKCore.ImageDownloadTask(
            closure: {
              [imageLoader] imageView,
              size,
              cornerRadius in
              return imageLoader.loadImage(url: url, imageView: imageView, size: size, cornerRadius: cornerRadius)
            }
          ))
        }
        
        return SwapTokenPickerCell.Model(
          identifier: token.identifier,
          isHighlightable: true,
          isSelectable: true,
          selectionHandler: {
            
          },
          cellContentModel: SwapTokenPickerCellContentView.Model(
            image: image,
            backgroundColor: .clear,
            tokenSymbol: token.symbol,
            tokenName: token.name,
            balance: token.balance,
            balanceInBaseCurrency: token.balanceInBaseCurrency
          )
        )
      }
      
      let suggestedTokenModels = suggestedTokens.map { token in
        let image: TKListItemIconImageView.Model.Image
        switch token.image {
        case .ton:
          image = .image(.TKCore.Icons.Size44.tonLogo)
        case .url(let url):
          image = .asyncImage(TKCore.ImageDownloadTask(
            closure: {
              [imageLoader] imageView,
              size,
              cornerRadius in
              return imageLoader.loadImage(url: url, imageView: imageView, size: size, cornerRadius: cornerRadius)
            }
          ))
        }
        return SwapTokenPickerSuggestedCell.Model(identifier: "suggested_\(token.identifier)",
                                                  isHighlightable: true,
                                                  isSelectable: true,
                                                  selectionHandler: {
                                                    
                                                  },
                                                  cellContentModel: SwapTokenPickerSuggestedCellContentView.Model(image: image, title: token.symbol))
      }
      self.didUpdateTokens?(models, suggestedTokenModels)
    }
    
    swapTokenPickerController.didUpdateSelectedTokenIndex = { [weak self] index in
      self?.didUpdateSelectedToken?(index)
    }
  }
}
