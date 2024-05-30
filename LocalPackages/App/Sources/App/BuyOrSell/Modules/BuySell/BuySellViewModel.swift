import UIKit
import KeeperCore
import BigInt
import TKUIKit

struct BuySellInputModel {
    let convertedValue: String
    let inputValue: String
    let inputSymbol: String
    let maximumFractionDigits: Int
    let remainingAttributedText: NSAttributedString
    let isContinueButtonEnabled: Bool
}

struct BuySellMethodSection: Hashable {
    let items: [BuySellMethodCell.Model]
}

protocol BuySellModuleOutput: AnyObject {
}

protocol BuySellModuleInput: AnyObject {
}

protocol BuySellViewModel: AnyObject {
    var didUpdateInputConvertedValue: ((String) -> Void)? { get set}
    var didUpdateInput: ((BuySellInputModel) -> Void)? { get set }
    var didUpdateMethods: ((BuySellMethodSection) -> Void)? { get set }
    
    func viewDidLoad()
    func didEditInput(_ input: String?)
    func toggleInputMode()
}

extension BuySellMethodCellContentView.Model {
    private static let circleSize = CGSize(width: 26, height: 26)
    private static let cardSize = CGSize(width: 36, height: 26)
    private static let cardRadius: CGFloat = 5.0
    
    static let creditCard: BuySellMethodCellContentView.Model = {
        let cardsImages: [UIImage] = [
            .TKUIKit.Icons.Size36.mastercardCard.withRenderingMode(.alwaysOriginal),
            .TKUIKit.Icons.Size36.visaCard.withRenderingMode(.alwaysOriginal),
        ]
        
        let cards = cardsImages.compactMap {
            TKListItemIconImageView.Model(
                image: .image($0),
                tintColor: .clear,
                backgroundColor: .clear,
                size: .init(width: 36, height: 36)
            )
        }
        
        let chipsModel = TKTokenChips.Model(
            chipImages: cards,
            chipSize: cardSize,
            chipRadius: cardRadius,
            minimumChipOffset: -4,
            borderColor: .clear,
            borderWidth: 0
        )
        
        return BuySellMethodCellContentView.Model(
            title: "Credit Card",
            chipsModel: chipsModel
        )
    }()
    
    static let mirCard: BuySellMethodCellContentView.Model = {
        let card = TKListItemIconImageView.Model(
            image: .image(.TKUIKit.Icons.Size36.mirCard.withRenderingMode(.alwaysOriginal)),
            tintColor: .clear,
            backgroundColor: .clear,
            size: .init(width: 36, height: 36)
        )
        
        let chipsModel = TKTokenChips.Model(
            chipImages: [card],
            chipSize: cardSize,
            chipRadius: cardRadius,
            minimumChipOffset: -4,
            borderColor: .clear,
            borderWidth: 0
        )
        
        return BuySellMethodCellContentView.Model(
            title: "Credit Card",
            symbol: "RUB",
            chipsModel: chipsModel
        )
    }()
    
    static let cryptoCurrency: BuySellMethodCellContentView.Model = {
        let chipImages: [UIImage] = [
            .TKUIKit.Icons.Size24.ethIcon.withRenderingMode(.alwaysOriginal),
            .TKUIKit.Icons.Size24.btcIcon.withRenderingMode(.alwaysOriginal),
            .TKUIKit.Icons.Size24.usdtIcon.withRenderingMode(.alwaysOriginal),
        ]
        
        let chipImageModels = chipImages.map {
            TKListItemIconImageView.Model(
                image: .image($0),
                tintColor: .clear,
                backgroundColor: .Background.content,
                size: .init(width: 26, height: 26)
            )
        }
        
        let chipsModel = TKTokenChips.Model(
            chipImages: chipImageModels,
            chipSize: .init(width: 26, height: 26),
            chipRadius: 13,
            minimumChipOffset: 5,
            borderColor: .Background.content,
            borderWidth: 2
        )
        
        return BuySellMethodCellContentView.Model(
            title: "Cryptocurrency",
            chipsModel: chipsModel
        )
    }()
    
    static let appleCard: BuySellMethodCellContentView.Model = {
        let card = TKListItemIconImageView.Model(
            image: .image(.TKUIKit.Icons.Size36.appleCard.withRenderingMode(.alwaysOriginal)),
            tintColor: .clear,
            backgroundColor: .clear,
            size: .init(width: 36, height: 36)
        )
        
        let chipsModel = TKTokenChips.Model(
            chipImages: [card],
            chipSize: cardSize,
            chipRadius: cardRadius,
            minimumChipOffset: -4,
            borderColor: .clear,
            borderWidth: 0
        )
        
        return BuySellMethodCellContentView.Model(
            title: "Apple pay",
            chipsModel: chipsModel
        )
    }()
}
