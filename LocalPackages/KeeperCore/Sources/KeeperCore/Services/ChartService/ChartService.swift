import Foundation

enum ChartServiceError: Error, Equatable {
    case badResponse
    case cancelled
    case networkError
    case apiError(message: String?)
}

protocol ChartService {
    func loadChartData(
        period: Period,
        asset: ChartAsset,
        currency: Currency,
        network: Network
    ) async throws(ChartServiceError) -> [Coordinate]
    func getChartData(
        period: Period,
        asset: ChartAsset,
        currency: Currency,
        network: Network
    ) -> [Coordinate]?
}

final class ChartServiceImplementation: ChartService {
    private let apiProvider: APIProvider
    private let tradingAPI: TradingAPI
    private let tradingRequestContextProvider: TradingRequestContextProvider
    private let repository: ChartDataRepository

    init(
        apiProvider: APIProvider,
        tradingAPI: TradingAPI,
        tradingRequestContextProvider: TradingRequestContextProvider,
        repository: ChartDataRepository
    ) {
        self.apiProvider = apiProvider
        self.tradingAPI = tradingAPI
        self.tradingRequestContextProvider = tradingRequestContextProvider
        self.repository = repository
    }

    func loadChartData(
        period: Period,
        asset: ChartAsset,
        currency: Currency,
        network: Network
    ) async throws(ChartServiceError) -> [Coordinate] {
        let coordinates: [Coordinate]
        switch asset {
        case let .multichain(assetId):
            let requestContext = await tradingRequestContextProvider.makeRequestContext()
            do {
                coordinates = try await tradingAPI.getAssetChart(
                    requestContext: requestContext,
                    assetId: assetId,
                    period: period,
                    currency: currency
                )
            } catch {
                throw mapTradingAPIError(error)
            }
        case let .legacy(token):
            do {
                coordinates = try await apiProvider.api(network).getChart(
                    token: token,
                    period: period,
                    currency: currency
                )
            } catch {
                throw mapLegacyAPIError(error)
            }
        }
        guard !coordinates.isEmpty else {
            throw .badResponse
        }
        try? repository.saveChartData(
            coordinates: coordinates,
            period: period,
            token: asset.cacheToken,
            currency: currency,
            network: network
        )
        return coordinates
    }

    func getChartData(
        period: Period,
        asset: ChartAsset,
        currency: Currency,
        network: Network
    ) -> [Coordinate]? {
        return repository.getChartData(
            period: period,
            token: asset.cacheToken,
            currency: currency,
            network: network
        )
    }
}

private extension ChartServiceImplementation {
    func mapTradingAPIError(_ error: TradingAPIError) -> ChartServiceError {
        switch error {
        case let .badUrl(underlying),
             let .transportError(underlying):
            if underlying?.isCancelledError == true {
                return .cancelled
            }
            return .networkError
        case .badResponse:
            return .badResponse
        case let .badStatus(message):
            return .apiError(message: message)
        case .notFound:
            return .apiError(message: error.localizedDescription)
        case let .unknown(underlying):
            if underlying?.isCancelledError == true {
                return .cancelled
            }
            return .apiError(message: underlying?.localizedDescription ?? error.localizedDescription)
        }
    }

    func mapLegacyAPIError(_ error: Error) -> ChartServiceError {
        if error.isCancelledError {
            return .cancelled
        }

        switch error {
        case let urlError as URLError:
            return urlError.isCancelledError ? .cancelled : .networkError
        case API.APIError.incorrectURL:
            return .networkError
        case API.APIError.incorrectResponse:
            return .badResponse
        case let API.APIError.serverError(statusCode):
            return .apiError(message: "status code: \(statusCode)")
        case is DecodingError:
            return .badResponse
        default:
            return .apiError(message: error.localizedDescription)
        }
    }
}
