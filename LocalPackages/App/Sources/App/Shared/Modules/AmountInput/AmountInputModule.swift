import BigInt
import UIKit

enum AmountInputSymbol {
    case icon(UIImage)
    case text(String)
}

struct AmountInputQuickOption: Equatable {
    let id: String
    let title: String
    /// Source amount in major units, for example 50 USD.
    let amount: Decimal
}

protocol AmountInputModuleOutput: AnyObject {
    var isEnable: Bool { get }

    var didUpdateSourceAmount: ((BigUInt) -> Void)? { get set }
    var didUpdateIsEnableState: ((Bool) -> Void)? { get set }
    var didTapConverted: (() -> Void)? { get set }
}

protocol AmountInputModuleInput: AnyObject {
    var sourceUnit: AmountInputUnit { get set }
    var destinationUnit: AmountInputUnit { get set }
    var rate: NSDecimalNumber { get set }
    var sourceBalance: BigUInt { get set }
    var minimumSourceAmount: BigUInt? { get set }
    var isMaxButtonVisible: Bool { get set }
    var maxReserve: BigUInt { get set }
    var maxHint: String? { get set }
    var isBalanceVisible: Bool { get set }
    var isCurrencySwitchEnabled: Bool { get set }
    var isConvertedAmountHidden: Bool { get set }
    var isConvertedShimmering: Bool { get set }
    var quickOptions: [AmountInputQuickOption] { get set }
    var isConvertedSelectable: Bool { get set }
    var convertedLeadingImage: UIImage? { get set }
    var convertedLeadingImageURL: URL? { get set }

    func reset()
    func setInitialSourceAmount(amount: BigUInt)
}
