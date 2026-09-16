@MainActor
final class TokenManagementCategoryViewModel {
    private struct QueryKey: Hashable {
        let query: String
        let hidesDustBalances: Bool
    }

    private let categoryID: String
    private let allCategoryID: String
    private let service: TokenManagementService

    private var queryViewModels = [QueryKey: TokenManagementQueryViewModel]()

    init(
        categoryID: String,
        allCategoryID: String,
        service: TokenManagementService
    ) {
        self.categoryID = categoryID
        self.allCategoryID = allCategoryID
        self.service = service
    }

    func queryViewModel(
        for query: String?,
        hidesDustBalances: Bool
    ) -> TokenManagementQueryViewModel {
        let key = QueryKey(
            query: query ?? "",
            hidesDustBalances: hidesDustBalances
        )
        if let queryViewModel = queryViewModels[key] {
            return queryViewModel
        }

        let queryViewModel = TokenManagementQueryViewModel(
            query: query,
            categoryID: categoryID,
            allCategoryID: allCategoryID,
            hidesDustBalances: hidesDustBalances,
            service: service
        )
        queryViewModels[key] = queryViewModel
        return queryViewModel
    }

    func disappeared() {
        queryViewModels.values.forEach { $0.disappeared() }
    }
}
