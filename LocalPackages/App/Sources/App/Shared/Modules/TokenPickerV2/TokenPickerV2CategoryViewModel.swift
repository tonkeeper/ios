import KeeperCore
import TKUIKit

@MainActor
final class TokenPickerV2CategoryViewModel {
    private let category: TokenPickerV2ChainFilter
    private let tokenPickerModel: any TokenPickerV2Model
    private let amountFormatter: AmountFormatter
    private let currencyStore: CurrencyStore
    private let displayMode: SendTokenV2PickerDisplayMode

    private var queryViewModels = [String: TokenPickerV2QueryViewModel]()

    init(
        category: TokenPickerV2ChainFilter,
        displayMode: SendTokenV2PickerDisplayMode,
        tokenPickerModel: any TokenPickerV2Model,
        amountFormatter: AmountFormatter,
        currencyStore: CurrencyStore
    ) {
        self.category = category
        self.tokenPickerModel = tokenPickerModel
        self.amountFormatter = amountFormatter
        self.currencyStore = currencyStore
        self.displayMode = displayMode
    }

    func queryViewModel(for query: String?) -> TokenPickerV2QueryViewModel {
        let key = query ?? ""
        if let queryViewModel = queryViewModels[key] {
            return queryViewModel
        }

        let queryViewModel = TokenPickerV2QueryViewModel(
            query: query,
            category: category,
            displayMode: displayMode,
            tokenPickerModel: tokenPickerModel,
            amountFormatter: amountFormatter,
            currencyStore: currencyStore
        )
        queryViewModels[key] = queryViewModel
        return queryViewModel
    }

    func disappeared() {
        queryViewModels.values.forEach { $0.disappeared() }
    }

    func invalidateCachedQueries() {
        queryViewModels.values.forEach { $0.disappeared() }
        queryViewModels.removeAll()
    }
}
