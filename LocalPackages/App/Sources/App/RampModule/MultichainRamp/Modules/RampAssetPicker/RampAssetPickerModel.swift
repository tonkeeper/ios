import Foundation
import KeeperCore
import TKLogging

final class RampAssetPickerModel: TokenPickerV2Model {
    private let multichainRampService: MultichainRampService
    private let currencyStore: CurrencyStore
    private let preferredFiat: String?
    private let walletId: String?

    let initialState: TokenPickerV2ModelState

    private(set) var catalogSearchSort: MultichainAssetSearchSort = .marketCap

    var showsCatalogSortControl: Bool {
        false
    }

    init(
        multichainRampService: MultichainRampService,
        currencyStore: CurrencyStore,
        preferredFiat: String? = nil,
        walletId: String?
    ) {
        self.multichainRampService = multichainRampService
        self.currencyStore = currencyStore
        self.preferredFiat = preferredFiat
        self.walletId = walletId
        initialState = TokenPickerV2ModelState(
            filters: [.all],
            displayMode: .rampAsset,
            initialFilter: .all
        )
    }

    func setCatalogSearchSort(_ sort: MultichainAssetSearchSort) {}

    func loadFilters() async throws(MultichainServiceError) -> [TokenPickerV2ChainFilter]? {
        do {
            let response = try await multichainRampService.getOnrampChains(
                query: OnRampChainsQuery(
                    fiat: preferredFiat ?? currencyStore.state.code,
                    paymentMethod: nil
                ),
                walletId: walletId
            )
            var filters: [TokenPickerV2ChainFilter] = [.all]
            var seen = Set<MultichainChain>()
            for chainId in response.chains {
                guard let chain = MultichainChain(assetIdChain: chainId),
                      seen.insert(chain).inserted
                else {
                    continue
                }
                filters.append(.chain(chain))
            }
            return filters
        } catch {
            Log.multichainRamp.failure(
                "onramp chains loading failed",
                error: error
            )
            guard let error = error as? MultichainRampAPIError else {
                throw .apiError(message: error.localizedDescription)
            }
            throw mapError(error)
        }
    }

    func loadAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit: Int,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        do {
            let configuration = try await multichainRampService.getOnrampConfiguration(
                query: makeOnRampQuery(
                    filter: filter,
                    searchQuery: normalizedQuery(query),
                    cursor: cursor,
                    limit: limit
                ),
                walletId: walletId
            )

            let assets = configuration.assets.compactMap { asset -> MultichainAsset? in
                let multichainAsset = makeAsset(from: asset)
                guard multichainAsset.asset.chain != nil else {
                    return nil
                }
                return multichainAsset
            }

            return TokenPickerLoadResult(
                assets: assets,
                nextCursor: configuration.nextCursor
            )
        } catch {
            Log.multichainRamp.failure(
                "onramp asset list loading failed",
                error: error,
                extraInfo: [
                    "filter": "\(filter)",
                    "hasQuery": "\(normalizedQuery(query) != nil)",
                    "isPaging": "\(cursor != nil)",
                ]
            )
            guard let error = error as? MultichainRampAPIError else {
                throw .apiError(message: error.localizedDescription)
            }
            throw mapError(error)
        }
    }
}

private extension RampAssetPickerModel {
    func makeOnRampQuery(
        filter: TokenPickerV2ChainFilter,
        searchQuery: String? = nil,
        cursor: String? = nil,
        limit: Int? = nil
    ) -> OnRampConfigurationQuery {
        OnRampConfigurationQuery(
            destinationChain: destinationChain(for: filter),
            fiat: preferredFiat ?? currencyStore.state.code,
            paymentMethod: nil,
            searchQuery: searchQuery,
            cursor: cursor,
            limit: limit
        )
    }

    func destinationChain(for filter: TokenPickerV2ChainFilter) -> String? {
        apiChain(for: filter)?.onrampDestinationChainPath()
    }

    func apiChain(for filter: TokenPickerV2ChainFilter) -> MultichainChain? {
        switch filter {
        case .all, .perpetuals:
            return nil
        case let .chain(chain):
            return chain
        }
    }

    func makeAsset(from configurationAsset: OnRampConfigurationAsset) -> MultichainAsset {
        let assetDetails = MultichainAssetDetails(
            assetId: configurationAsset.assetId,
            name: networkName(for: configurationAsset),
            symbol: configurationAsset.symbol,
            decimals: configurationAsset.decimals,
            image: configurationAsset.image ?? ""
        )

        return MultichainAsset(
            asset: assetDetails,
            price: MultichainAssetPrice(
                prices: [:],
                diff24h: [:],
                diff7d: [:],
                diff30d: [:]
            ),
            balance: .zero
        )
    }

    func networkName(for asset: OnRampConfigurationAsset) -> String {
        if let networkName = asset.networkName, !networkName.isEmpty {
            return networkName
        }

        return MultichainAssetDetails(
            assetId: asset.assetId,
            name: "",
            symbol: asset.symbol,
            decimals: asset.decimals,
            image: ""
        ).chain?.shortDisplayTitle ?? ""
    }

    func normalizedQuery(_ query: String?) -> String? {
        guard let query else {
            return nil
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func mapError(_ error: MultichainRampAPIError) -> MultichainServiceError {
        switch error {
        case let .badRequest(message, _, _),
             let .notFound(message, _),
             let .internalServerError(message, _):
            return .apiError(message: message)
        case .cancelled:
            return .cancelled
        case .badResponse, .transportError:
            return .apiError(message: nil)
        case let .unknown(statusCode):
            return .apiError(message: "HTTP \(statusCode)")
        }
    }
}
