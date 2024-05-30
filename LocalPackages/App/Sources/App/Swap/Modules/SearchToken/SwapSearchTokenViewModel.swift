import Foundation
import KeeperCore
import TKUIKit
import TKCore

protocol PartiallyEquatable {
    var fields: [String] { get }
}

extension PartiallyEquatable {
    func isPartiallyEqual(by text: String) -> Bool {
        let lowercasedText = text.lowercased()
        for field in self.fields {
            let lowercasedField = field.lowercased()
            if lowercasedField.contains(lowercasedText) {
                return true
            }
        }
        return false
    }
}

extension JettonInfo: PartiallyEquatable {
    var fields: [String] {
        [name, symbol].compactMap { $0 }
    }
}

struct SwapSearchTokenModel {
    let sections: [SwapSearchTokenSection]
}

enum SwapSearchTokenSection: Hashable {
    case suggested(items: [SwapSearchTokenSuggestedCell.Model])
    case other(items: [SwapSearchTokenOtherCell.Model])
}

protocol SwapSearchTokenModuleOutput: AnyObject {
    var didFinish: (() -> Void)? { get set }
    var didSelectToken: ((JettonInfo) -> Void)? { get set }
}

protocol SwapSearchTokenModuleInput: AnyObject {
}

protocol SwapSearchTokenViewModel: AnyObject {
    var didUpdateModel: ((SwapSearchTokenModel) -> Void)? { get set }
    
    func viewDidLoad()
    func didTapCloseButton()
    func didUpdateText(text: String)
    func didSelectCell(_ section: SwapSearchTokenSection, _ itemIndexPath: Int)
}

final class SwapSearchTokenViewModelImplementation: SwapSearchTokenViewModel, SwapSearchTokenModuleInput, SwapSearchTokenModuleOutput {
    
    // MARK: - SwapSearchTokenModuleOutput
    
    var didFinish: (() -> Void)?
    var didSelectToken: ((JettonInfo) -> Void)?
    
    // MARK: - SwapSearchTokenModuleInput
    
    // MARK: - SwapSearchTokenViewModel
    
    private var searchText: String = "" {
        didSet {
            filterTokens(tokens: &tokens, searchText: searchText)
        }
    }
    
    private var tokens: [JettonInfo] = [] {
        didSet {
            filterTokens(tokens: &tokens, searchText: searchText)
        }
    }
    
    private var filteredTokens: [JettonInfo] = [] {
        didSet {
            Task { @MainActor in
                self.didUpdateModel?(self.mapSwapSearchTokenModel(filteredTokens))
            }
        }
    }
    
    var didUpdateModel: ((SwapSearchTokenModel) -> Void)?
    
    func viewDidLoad() {
        Task {
            swapSearchTokenController.didUpdateModel = { [weak self] jettons in
                guard let self else { return }
                self.tokens = jettons
            }
            await swapSearchTokenController.start()
        }
    }
    
    func didTapCloseButton() {
        didFinish?()
    }
    
    func didUpdateText(text: String) {
        self.searchText = text
    }
    
    func didSelectCell(_ section: SwapSearchTokenSection, _ itemIndexPath: Int) {
        
    }
    
    // MARK: - Image Loader
    
    private let imageLoader = ImageLoader()
    
    // MARK: - Dependencies
    
    private let swapSearchTokenController: SwapSearchTokenController
    
    init(swapSearchTokenController: SwapSearchTokenController) {
        self.swapSearchTokenController = swapSearchTokenController
    }
    
}

private extension SwapSearchTokenViewModelImplementation {
    func filterTokens(tokens: inout [JettonInfo], searchText: String) {
        if searchText.isEmpty {
            filteredTokens = tokens
            return
        }
        filteredTokens = tokens.filter { $0.isPartiallyEqual(by: searchText) }
    }
}

private extension SwapSearchTokenViewModelImplementation {
    func mapSwapSearchTokenModel(_ jettons: [JettonInfo]) -> SwapSearchTokenModel {
        let otherItems: [SwapSearchTokenOtherCell.Model] = jettons
            .compactMap { jetton in
                let iconTask = TKCore.ImageDownloadTask(
                    closure: { [imageLoader] imageView, size, cornerRadius in
                        return imageLoader.loadImage(
                            url: jetton.imageURL,
                            imageView: imageView,
                            size: size,
                            cornerRadius: cornerRadius
                        )
                    }
                )
                
                let iconModel = TKListItemIconImageView.Model(
                    image: .asyncImage(iconTask),
                    tintColor: .Background.content,
                    backgroundColor: .Background.content,
                    size: .init(width: 44, height: 44)
                )
                
                var tagModel: TKTagView.Model?
                if jetton.verification == .whitelist {
                    tagModel = .init(title: "TON".withTextStyle(.body4, color: .Text.secondary))
                }
                
                let leftContentStackViewModel = TKListItemContentStackView.Model(
                    titleSubtitleModel: .init(
                        title: jetton.symbol?.withTextStyle(.label1, color: .Text.primary),
                        tagModel: tagModel,
                        subtitle: jetton.name.withTextStyle(.body2, color: .Text.secondary)
                    ),
                    description: nil
                )
                
                let rightContentStackViewModel = TKListItemContentStackView.Model(
                    titleSubtitleModel: .init(
                        title: "0".withTextStyle(.label1, color: .Text.tertiary),
                        tagModel: nil,
                        subtitle: nil
                    ),
                    description: nil
                )
                
                let contentModel = TKListItemContentView.Model(
                    leftContentStackViewModel: leftContentStackViewModel,
                    rightContentStackViewModel: rightContentStackViewModel
                )
                
                let cellContentModel = SwapSearchTokenOtherCellContentView.Model(
                    iconModel: iconModel,
                    contentModel: contentModel
                )
                
                let identifier = "\(jetton.hashValue)"
                let cellModel = SwapSearchTokenOtherCell.Model(
                    identifier: identifier,
                    selectionHandler: { [weak self] in
                        self?.didSelectToken?(jetton)
                        self?.didFinish?()
                    },
                    cellContentModel: cellContentModel
                )
                
                return cellModel
            }
        
        let suggestedItems: [SwapSearchTokenSuggestedCell.Model] = jettons
            .compactMap { jetton in
                if jetton.verification != .whitelist {
                    return nil
                }
                
                let iconTask = TKCore.ImageDownloadTask(
                    closure: { [imageLoader] imageView, size, cornerRadius in
                        return imageLoader.loadImage(
                            url: jetton.imageURL,
                            imageView: imageView,
                            size: size,
                            cornerRadius: cornerRadius
                        )
                    }
                )
                
                let iconModel = TKListItemIconImageView.Model.Image.asyncImage(iconTask)
                
                let cellContentModel = SwapSearchTokenSuggestedCellContentView.Model(
                    tokenModel: TKTokenTagView.Model(
                        iconModel: iconModel,
                        title: jetton.symbol?.withTextStyle(.label1, color: .Button.tertiaryForeground),
                        accessoryType: nil
                    ),
                    didSelect: { [weak self] in
                        self?.didSelectToken?(jetton)
                        self?.didFinish?()
                    }
                )
                
                let identifier = "\(jetton.hashValue)"
                let cellModel = SwapSearchTokenSuggestedCell.Model(
                    identifier: identifier,
                    cellContentModel: cellContentModel
                )
                
                return cellModel
            }
        
        let otherSection = SwapSearchTokenSection.other(items: otherItems)
        let suggestedSection = SwapSearchTokenSection.suggested(items: suggestedItems)
        
        return .init(sections: [suggestedSection, otherSection])
    }
}

extension SwapSearchTokenSection {
    var headerTitle: String {
        switch self {
        case .suggested:
            return "Suggested"
        case .other:
            return "Other"
        }
    }
}
