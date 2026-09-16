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
        let batch: TKKandelabrAPI.Components.Schemas.GetCandlesResponse
        do {
            batch = try await kandelabr.candles(
                ticker: ticker,
                resolution: timeframe.resolution,
                limit: limit,
                startTs: nil,
                endTs: endTs
            )
        } catch KandelabrAPIError.badRequest, KandelabrAPIError.notFound {
            if case .latest = window {
                Log.w("🪵 Perps: kandelabr snapshot rejected — ticker=\(ticker) resolution=\(timeframe.resolution)")
            }
            return .rejected
        } catch {
            switch window {
            case .latest:
                Log.w("🪵 Perps: kandelabr snapshot failed — \(error)")
            case .older:
                Log.w("🪵 Perps: kandelabr page failed — \(error)")
            }
            return .unavailable
        }
        if case .latest = window, batch.candles.isEmpty {
            Log.w("🪵 Perps: kandelabr snapshot empty — ticker=\(ticker) resolution=\(timeframe.resolution)")
        }
        return .response(batch)
    }

    private func wireLimit(for count: Int64) -> Int32 {
        let count = timeframe == .h12 ? count * 3 : count
        return Int32(clamping: count)
    }
}
