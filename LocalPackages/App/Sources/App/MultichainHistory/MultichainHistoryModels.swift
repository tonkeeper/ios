import Foundation
import KeeperCore
import TKLocalize
import UIKit

enum MultichainHistoryChainFilter: Hashable {
    case all
    case chain(MultichainChain)

    var apiChain: MultichainChain? {
        switch self {
        case .all:
            return nil
        case let .chain(chain):
            return chain
        }
    }
}

enum MultichainHistoryTypeFilter: Hashable, CaseIterable {
    case all
    case send
    case receive
    case swap
    case perps
    case spam

    var title: String {
        switch self {
        case .all:
            return TKLocales.History.Tab.all
        case .send:
            return TKLocales.History.Tab.sent
        case .receive:
            return TKLocales.History.Tab.received
        case .swap:
            return TKLocales.ActionTypes.Future.swap
        case .perps:
            return TKLocales.History.Tab.perpetuals
        case .spam:
            return TKLocales.History.Tab.spam
        }
    }

    var apiActivityTypeFilter: MultichainActivityTypeFilter? {
        switch self {
        case .all, .spam:
            return nil
        case .send:
            return .send
        case .receive:
            return .receive
        case .swap:
            return .swap
        case .perps:
            return .perps
        }
    }

    var admitsPerps: Bool {
        switch self {
        case .all, .perps:
            return true
        case .send, .receive, .swap, .spam:
            return false
        }
    }
}

enum MultichainHistoryCategory: Hashable {
    case chain(chainFilter: MultichainHistoryChainFilter, typeFilter: MultichainHistoryTypeFilter)
    case asset(assetId: String, typeFilter: MultichainHistoryTypeFilter)

    var typeFilter: MultichainHistoryTypeFilter {
        switch self {
        case let .chain(_, typeFilter), let .asset(_, typeFilter):
            return typeFilter
        }
    }
}

extension MultichainHistoryCategory {
    var isSpamCategory: Bool {
        typeFilter == .spam
    }

    func fetchActivities(
        using service: MultichainService,
        state: MultichainWalletState,
        limit: Int,
        cursor: String?,
        hideDust: Bool?,
        showsPerps: Bool
    ) async throws(MultichainServiceError) -> MultichainWalletActivitiesPage {
        switch self {
        case let .chain(chainFilter, typeFilter):
            return try await service.getWalletActivities(
                state: state,
                limit: limit,
                cursor: cursor,
                chain: chainFilter.apiChain,
                assetId: nil,
                activityTypeFilter: typeFilter.apiActivityTypeFilter,
                showPerps: showsPerps && typeFilter.admitsPerps ? true : nil,
                hideDust: hideDust
            )
        case let .asset(assetId, typeFilter):
            return try await service.getWalletActivities(
                state: state,
                limit: limit,
                cursor: cursor,
                chain: nil,
                assetId: assetId,
                activityTypeFilter: typeFilter.apiActivityTypeFilter,
                showPerps: showsPerps && typeFilter.admitsPerps ? true : nil,
                hideDust: hideDust
            )
        }
    }
}

struct MultichainHistoryChainTab: Identifiable, Equatable {
    let id: MultichainHistoryChainFilter
    let title: String
    let image: UIImage?
    let isSelectable: Bool

    static func == (lhs: MultichainHistoryChainTab, rhs: MultichainHistoryChainTab) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.isSelectable == rhs.isSelectable
    }
}

struct MultichainHistoryTypeFilterItem: Identifiable, Equatable {
    let id: MultichainHistoryTypeFilter
    let title: String
    let isSelected: Bool
}

struct MultichainHistoryActivityIdentity: Hashable {
    let txIds: [String]
    let activityType: MultichainActivityType
    let direction: MultichainActivityDirection
    let fromChain: MultichainChain?
    let toChain: MultichainChain?
    let walletAddress: String?
    let fromAddress: String?
    let toAddress: String?
    let outTokenAssetId: String?
    let inTokenAssetId: String?
    let outAmount: String?
    let inAmount: String?

    init(activity: MultichainActivity) {
        self.txIds = Self.normalizedTxIds(activity.txIds)
        self.activityType = activity.activityType
        self.direction = activity.direction
        self.fromChain = activity.fromChain
        self.toChain = activity.toChain
        self.walletAddress = activity.walletAddress
        self.fromAddress = activity.fromAddress
        self.toAddress = activity.toAddress
        self.outTokenAssetId = activity.outToken?.assetId
        self.inTokenAssetId = activity.inToken?.assetId
        self.outAmount = activity.outAmount
        self.inAmount = activity.inAmount
    }
}

private extension MultichainHistoryActivityIdentity {
    static func normalizedTxIds(_ txIds: [String]) -> [String] {
        Array(
            Set(
                txIds
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }
}

struct MultichainHistoryActivityItem: Identifiable, Equatable {
    typealias ID = MultichainHistoryActivityIdentity

    struct Amount: Equatable {
        enum Style: Equatable {
            case primary
            case positive
            case negative
        }

        let text: String
        let chainTitle: String?
        let style: Style
    }

    let id: ID
    let activity: MultichainActivity
    let title: String
    let subtitle: String?
    let comment: String?
    let time: String
    let icon: UIImage
    let primaryAmount: Amount?
    let secondaryAmount: Amount?
    let status: MultichainActivityStatus
    let nft: MultichainActivityNFT?

    static func == (lhs: MultichainHistoryActivityItem, rhs: MultichainHistoryActivityItem) -> Bool {
        lhs.id == rhs.id
            && lhs.activity == rhs.activity
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.comment == rhs.comment
            && lhs.time == rhs.time
            && lhs.primaryAmount == rhs.primaryAmount
            && lhs.secondaryAmount == rhs.secondaryAmount
            && lhs.status == rhs.status
            && lhs.nft == rhs.nft
    }
}

struct MultichainHistoryEventKey: Hashable {
    let tonEventLt: Int64
    let walletAddress: String?

    init?(activity: MultichainActivity) {
        guard let tonEventLt = activity.tonEventLt else {
            return nil
        }
        self.tonEventLt = tonEventLt
        self.walletAddress = activity.walletAddress
    }
}

private extension MultichainActivity {
    var tonEventLt: Int64? {
        guard fromChain == .ton, toChain == .ton else {
            return nil
        }
        return blockNumber
    }
}

struct MultichainHistoryActivityGroup: Identifiable, Equatable {
    let id: MultichainHistoryActivityItem.ID
    let items: [MultichainHistoryActivityItem]

    init?(items: [MultichainHistoryActivityItem]) {
        guard let first = items.first else {
            return nil
        }
        self.id = first.id
        self.items = items
    }
}

struct MultichainHistorySection: Identifiable, Equatable {
    let id: Date
    let title: String
    let groups: [MultichainHistoryActivityGroup]

    var items: [MultichainHistoryActivityItem] {
        groups.flatMap(\.items)
    }
}
