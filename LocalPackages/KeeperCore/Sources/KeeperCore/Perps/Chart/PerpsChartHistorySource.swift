import PerpsModels
import TKKandelabrAPI
import TKLogging

struct PerpsChartHistorySource {
    enum FetchResult {
        case response(TKKandelabrAPI.Components.Schemas.GetCandlesResponse)
        case rejected
        case unavailable
    }

    private enum Window {
        case latest
        case older
    }

    private let kandelabr: KandelabrAPI
    private let timeframe: PerpsChartTimeframe

    init(kandelabr: KandelabrAPI, timeframe: PerpsChartTimeframe) {
        self.kandelabr = kandelabr
        self.timeframe = timeframe
    }

    func latest(ticker: String, count: Int32) async -> FetchResult {
        await fetch(
            ticker: ticker,
            limit: wireLimit(for: Int64(count)),
            endTs: nil,
            window: .latest
        )
    }

    func older(ticker: String, before endTs: Int64, count: Int64) async -> FetchResult {
        await fetch(
            ticker: ticker,
            limit: wireLimit(for: count),
            endTs: endTs,
            window: .older
        )
    }

    private func fetch(
        ticker: String,
        limit: Int32,
        endTs: Int64?,
        window: Window
    ) async -> FetchResult {
        let volumeTicker = PerpsChartCandleMapper.volumeTicker(ticker)
        let responses: [TKKandelabrAPI.Components.Schemas.GetCandlesResponse]
        do {
            responses = try await kandelabr.candles(
                tickers: [ticker, volumeTicker],
                resolution: timeframe.resolution,
                limit: limit,
                endTs: endTs
            )
        } catch KandelabrAPIError.badRequest {
            if case .latest = window {
                Log.perps.w("kandelabr snapshot rejected — ticker=\(ticker) resolution=\(timeframe.resolution)")
            }
            return .rejected
        } catch {
            switch window {
            case .latest:
                Log.perps.w("kandelabr snapshot failed — \(error)")
            case .older:
                Log.perps.w("kandelabr page failed — \(error)")
            }
            return .unavailable
        }
        guard var batch = responses.first else { return .unavailable }
        if let volumes = responses.dropFirst().first,
           PerpsChartCandleMapper.matchesFeed(volumes, ticker: volumeTicker, timeframe: timeframe)
        {
            batch = PerpsChartCandleMapper.mergingVolumes(from: volumes, into: batch, timeframe: timeframe)
        }
        if case .latest = window, batch.candles.isEmpty {
            Log.perps.w("kandelabr snapshot empty — ticker=\(ticker) resolution=\(timeframe.resolution)")
        }
        return .response(batch)
    }

    private func wireLimit(for count: Int64) -> Int32 {
        let count = timeframe == .h12 ? count * 3 : count
        return Int32(clamping: count)
    }
}
