import Foundation
import KeeperCore
import TKUIKit
import TKCore
import BigInt

protocol TokenPickerModuleOutput: AnyObject {
  var didFinish: (() -> Void)? { get set }
  var didSelectToken: ((Token) -> Void)? { get set }
}

protocol TokenPickerViewModel: AnyObject {
  var didUpdateSelectedToken: ((Int?, _ scroll: Bool) -> Void)? { get set }
  var didUpdateSnapshot: ((_ snapshot: TokenPickerViewController.Snapshot) -> Void)? { get set }
  
  func viewDidLoad()
}

final class TokenPickerViewModelImplementation: TokenPickerViewModel, TokenPickerModuleOutput {
  
  // MARK: - TokenPickerModuleOutput
  
  var didFinish: (() -> Void)?
  var didSelectToken: ((Token) -> Void)?
  
  // MARK: - TokenPickerViewModel
  
  var didUpdateSelectedToken: ((Int?, _ scroll: Bool) -> Void)?  
  var didUpdateSnapshot: ((_ snapshot: TokenPickerViewController.Snapshot) -> Void)?
  
  func viewDidLoad() {
    tokenPickerModel.didUpdateState = { [weak self] state in
      self?.didUpdateState(state: state)
    }
  }
  // MARK: - Image Loading
  
  private let imageLoader = ImageLoader()
  
  // MARK: - State
  
  private let actor = SerialActor()
  
  // MARK: - Dependencies
  
  private let tokenPickerModel: TokenPickerModel
  private let amountFormatter: AmountFormatter
  
  // MARK: - Init
  
  init(tokenPickerModel: TokenPickerModel,
       amountFormatter: AmountFormatter) {
    self.tokenPickerModel = tokenPickerModel
    self.amountFormatter = amountFormatter
  }
}

private extension TokenPickerViewModelImplementation {
  func didUpdateState(state: TokenPickerModel.State) {
    Task {
      await self.actor.addTask(block: {
        var models = [TKUIListItemCell.Configuration]()
        
        let tonModel: TKUIListItemCell.Configuration = {
          let title = TonInfo.name
          let caption = self.amountFormatter.formatAmount(
            BigUInt(state.tonBalance.tonBalance.amount),
            fractionDigits: TonInfo.fractionDigits,
            maximumFractionDigits: 2,
            symbol: TonInfo.symbol
          )
          return self.createCellModel(
            id: TonInfo.name,
            image: .ton,
            title: title,
            tag: nil,
            caption: caption,
            selectionClosure: { [weak self] in
              guard let self else { return }
              if state.selectedToken == .ton {
                self.didFinish?()
              } else {
                self.didSelectToken?(.ton)
                self.didFinish?()
              }
            }
          )
        }()
        models.append(tonModel)
        
        let sortedJettonBalances = state.jettonBalances
          .sorted(by: {
            $0.converted > $1.converted
          })
        
        let jettonModels = sortedJettonBalances
          .map { jettonBalance in
          let title = jettonBalance.jettonBalance.item.jettonInfo.symbol ?? jettonBalance.jettonBalance.item.jettonInfo.name
          let caption = self.amountFormatter.formatAmount(
            jettonBalance.jettonBalance.quantity,
            fractionDigits: jettonBalance.jettonBalance.item.jettonInfo.fractionDigits,
            maximumFractionDigits: 2,
            symbol: jettonBalance.jettonBalance.item.jettonInfo.symbol
          )
          return self.createCellModel(
            id: jettonBalance.jettonBalance.item.jettonInfo.address.toRaw(),
            image: .url(jettonBalance.jettonBalance.item.jettonInfo.imageURL),
            title: title,
            tag: nil,
            caption: caption,
            selectionClosure: { [weak self] in
              guard let self else { return }
              if state.selectedToken == .jetton(jettonBalance.jettonBalance.item) {
                self.didFinish?()
              } else {
                self.didSelectToken?(.jetton(jettonBalance.jettonBalance.item))
                self.didFinish?()
              }
            }
          )
        }
        models.append(contentsOf: jettonModels)
        
        var selectedIndex: Int?
        switch state.selectedToken {
        case .ton:
          selectedIndex = 0
        case .jetton(let jettonItem):
          if let index = sortedJettonBalances.firstIndex(where: { $0.jettonBalance.item == jettonItem }) {
            print(jettonItem.jettonInfo.name)
            selectedIndex = index + 1
          }
        }
        
        var snapshot = TokenPickerViewController.Snapshot()
        snapshot.appendSections([.tokens])
        snapshot.appendItems(models, toSection: .tokens)
        await MainActor.run { [snapshot, selectedIndex] in
          self.didUpdateSnapshot?(snapshot)
          self.didUpdateSelectedToken?(selectedIndex, state.scrollToSelected)
        }
      })
    }
  }
  
  func createCellModel(id: String,
                       image: KeeperCore.TokenImage,
                       title: String,
                       tag: String?,
                       caption: String,
                       selectionClosure: (() -> Void)?) -> TKUIListItemCell.Configuration {
    var tagViewModel: TKUITagView.Configuration?
    if let tag {
      tagViewModel = TKUITagView.Configuration(
        text: tag,
        textColor: .Text.secondary,
        backgroundColor: .Background.contentTint
      )
    }
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
        title: title.withTextStyle(.label1, color: .Text.primary, alignment: .left),
        tagViewModel: tagViewModel,
        subtitle: caption.withTextStyle(.body2, color: .Text.secondary, alignment: .left),
        description: nil
      ),
      rightItemConfiguration: nil
    )
    
    let iconConfigurationImage: TKUIListItemImageIconView.Configuration.Image
    switch image {
    case .ton:
      iconConfigurationImage = .image(.TKCore.Icons.Size44.tonLogo)
    case .url(let url):
      iconConfigurationImage = .asyncImage(
        url,
        TKCore.ImageDownloadTask(
          closure: {
            [imageLoader] imageView,
            size,
            cornerRadius in
            return imageLoader.loadImage(
              url: url,
              imageView: imageView,
              size: size,
              cornerRadius: cornerRadius
            )
          }
        )
      )
    }
    
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        TKUIListItemImageIconView.Configuration(
          image: iconConfigurationImage,
          tintColor: .Icon.primary,
          backgroundColor: .Background.contentTint,
          size: CGSize(width: 44, height: 44),
          cornerRadius: 22
        )
      ),
      alignment: .center
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .none
    )
    
    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      isHighlightable: true,
      selectionClosure: selectionClosure
    )
  }
}
