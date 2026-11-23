import Foundation
import TKTonstakersAPI

protocol TonstakersAPI: Sendable {
    func rewards(
        address: String,
        from: Date?,
        limit: Int,
        offset: Int,
        includeTotal: Bool
    ) async throws(TonstakersAPIError) -> TonstakersRewardsPage

    func upcomingRewards(address: String) async throws(TonstakersAPIError) -> TonstakersUpcomingRewards
}

struct TonstakersAPIImplementation: TonstakersAPI {
    /// The feed also carries tsTON movements; only rewards are asked for.
    private static let rewardKind = "reward"

    private let makeClient: @Sendable () async -> Client

    init(makeClient: @escaping @Sendable () async -> Client) {
        self.makeClient = makeClient
    }

    func rewards(
        address: String,
        from: Date?,
        limit: Int,
        offset: Int,
        includeTotal: Bool
    ) async throws(TonstakersAPIError) -> TonstakersRewardsPage {
        // `from` scopes only the items; the total stays lifetime unless `from_total` is set too.
        let fromTimestamp = from.map { Int($0.timeIntervalSince1970) }
        let client = await makeClient()
        let response: Operations.tasks_get_rewards.Output
        do {
            response = try await client.tasks_get_rewards(
                query: .init(
                    address: address,
                    from: fromTimestamp,
                    limit: limit,
                    offset: offset,
                    total: includeTotal,
                    kind: Self.rewardKind,
                    from_total: fromTimestamp
                )
            )
        } catch {
            throw .transport(error)
        }

        switch response {
        case let .ok(ok):
            do {
                return try TonstakersRewardsPage(response: ok.body.json)
            } catch {
                throw .badResponse(error)
            }
        case .unprocessableContent:
            throw .badRequest
        case let .undocumented(statusCode, _):
            throw .badStatus(statusCode)
        }
    }

    func upcomingRewards(address: String) async throws(TonstakersAPIError) -> TonstakersUpcomingRewards {
        let client = await makeClient()
        let response: Operations.tasks_get_upcoming_rewards.Output
        do {
            response = try await client.tasks_get_upcoming_rewards(query: .init(address: address))
        } catch {
            throw .transport(error)
        }

        switch response {
        case let .ok(ok):
            do {
                return try TonstakersUpcomingRewards(response: ok.body.json)
            } catch {
                throw .badResponse(error)
            }
        case .unprocessableContent:
            throw .badRequest
        case let .undocumented(statusCode, _):
            throw .badStatus(statusCode)
        }
    }
}
