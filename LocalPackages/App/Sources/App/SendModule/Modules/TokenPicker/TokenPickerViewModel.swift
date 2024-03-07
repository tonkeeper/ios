import Foundation
import KeeperCore
import TKUIKit
import TKCore

protocol TokenPickerModuleOutput: AnyObject {
  var didFinish: (() -> Void)? { get set }
  var didSelectToken: ((Token) -> Void)? { get set }
}

protocol TokenPickerViewModel: AnyObject {
  var didUpdateTokens: (([TokenPickerCell.Model]) -> Void)? { get set }
  var didUpdateSelectedToken: ((Int) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectItemAt(index: Int)
}

final class TokenPickerViewModelImplementation: TokenPickerViewModel, TokenPickerModuleOutput {
  
  // MARK: - TokenPickerModuleOutput
  
  var didFinish: (() -> Void)?
  var didSelectToken: ((Token) -> Void)?
  
  // MARK: - TokenPickerViewModel
  
  var didUpdateTokens: (([TokenPickerCell.Model]) -> Void)?
  var didUpdateSelectedToken: ((Int) -> Void)?
  
  func viewDidLoad() {
    setupControllerBindings()
    tokenPickerController.start()
  }
  
  func didSelectItemAt(index: Int) {
    if tokenPickerController.isTokenSelectedAt(index: index) {
      didFinish?()
    } else {
      didSelectToken?(tokenPickerController.getTokenAt(index: index))
      didFinish?()
    }
  }
  
  // MARK: - Image Loading
  
  private let imageLoader = ImageLoader()
  
  // MARK: - Dependencies
  
  private let tokenPickerController: TokenPickerController
  
  // MARK: - Init
  
  init(tokenPickerController: TokenPickerController) {
    self.tokenPickerController = tokenPickerController
  }
}

private extension TokenPickerViewModelImplementation {
  func setupControllerBindings() {
    tokenPickerController.didUpdateTokens = { [weak self, imageLoader] tokens in
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
        
        return TokenPickerCell.Model(
          identifier: token.identifier,
          isHighlightable: true,
          isSelectable: true,
          selectionHandler: {
            
          },
          cellContentModel: TokenPickerCellContentView.Model(
            image: image,
            backgroundColor: .clear,
            tokenName: token.name,
            balance: token.balance
          )
        )
      }
      self.didUpdateTokens?(models)
    }
    
    tokenPickerController.didUpdateSelectedTokenIndex = { [weak self] index in
      self?.didUpdateSelectedToken?(index)
    }
  }
}
