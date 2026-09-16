import Foundation
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

struct TokenManagementAssetsPage {
    let balances: [TokenManagementBalanceItem]
    let nextCursor: String?
}

@MainActor
protocol TokenManagementService: AnyObject {
    var didLoadBalances: (([TokenManagementBalanceItem]) -> Void)? { get set }

    func loadAssets(
        chainID: String?,
        search: String?,
        hidesDustBalances: Bool,
        limit: Int,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenManagementAssetsPage

    func saveVisibilityChanges(_ changes: [MultichainAssetFilterChange]) throws -> TokenManagementVisibilityUpdate
}

struct TokenManagementChain: Identifiable {
    let id: String
    let title: String
    let badgeTitle: String
    let icon: UIImage?
}

struct TokenManagementBalanceItem: Identifiable, Equatable {
    let id: String
    let symbol: String
    let title: String
    let searchText: String
    let chainID: String
    let chainTag: String?
    let isHidden: Bool
    let avatarImageSource: AssetAvatarViewImageSource
    let subtitle: String
    let subtitleColor: TKColor
}

struct TokenManagementVisibilityUpdate {
    let changes: [MultichainAssetFilterChange]
    let visibleAssets: [MultichainAsset]
}

@MainActor
final class MultichainPortfolioTokenManagementService: TokenManagementService {
    var didLoadBalances: (([TokenManagementBalanceItem]) -> Void)?

    private let multichainState: MultichainWalletState
    private let multichainService: MultichainService
    private let visibilityChangesController: VisibilityChangesController
    private static let multichainFormatter = MultichainPortfolioAmountFormatting()

    private let displayCurrency: Currency
    private let amountFormatter: AmountFormatter
    private var assetsByID = [String: MultichainAsset]()

    init(
        multichainState: MultichainWalletState,
        multichainService: MultichainService,
        visibilityChangesController: VisibilityChangesController,
        displayCurrency: Currency,
        amountFormatter: AmountFormatter
    ) {
        self.multichainState = multichainState
        self.multichainService = multichainService
        self.visibilityChangesController = visibilityChangesController
        self.displayCurrency = displayCurrency
        self.amountFormatter = amountFormatter
    }

    func loadAssets(
        chainID: String?,
        search: String?,
        hidesDustBalances: Bool,
        limit: Int,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenManagementAssetsPage {
        var currencyCodes = [displayCurrency.code.lowercased()]
        if displayCurrency != .defaultCurrency {
            currencyCodes.append(Currency.defaultCurrency.code.lowercased())
        }

        let chain = chainID.flatMap(MultichainChain.init(rawValue:))
        let page = try await multichainService.getWalletAssets(
            state: multichainState,
            currencies: currencyCodes,
            assetIds: nil,
            capabilities: nil,
            chain: chain,
            search: search,
            availableOnly: nil,
            showHidden: true,
            hideDust: hidesDustBalances ? true : nil,
            limit: limit,
            cursor: cursor
        )

        for asset in page.assets {
            assetsByID[asset.asset.assetId] = asset
        }

        let balances = page.assets.compactMap { asset -> TokenManagementBalanceItem? in
            guard let chain = asset.asset.chain else {
                return nil
            }
            return Self.makeBalanceItem(
                asset: asset,
                chain: chain,
                displayCurrency: displayCurrency,
                amountFormatter: amountFormatter
            )
        }
        didLoadBalances?(balances)

        return TokenManagementAssetsPage(
            balances: balances,
            nextCursor: page.nextCursor
        )
    }

    func saveVisibilityChanges(_ changes: [MultichainAssetFilterChange]) throws -> TokenManagementVisibilityUpdate {
        guard !changes.isEmpty else {
            return TokenManagementVisibilityUpdate(
                changes: [],
                visibleAssets: visibleAssets
            )
        }

        let assets = Array(assetsByID.values)
        try visibilityChangesController.enqueue(
            changes,
            walletId: multichainState.walletId,
            assets: assets
        )
        for asset in visibilityChangesController.applyingPendingChanges(
            to: assets,
            walletId: multichainState.walletId
        ) {
            assetsByID[asset.asset.assetId] = asset
        }
        return TokenManagementVisibilityUpdate(
            changes: changes,
            visibleAssets: visibleAssets
        )
    }

    private var visibleAssets: [MultichainAsset] {
        assetsByID.values.filter { !$0.isHidden && $0.asset.chain != nil }
    }

    private static func makeBalanceItem(
        asset: MultichainAsset,
        chain: MultichainChain,
        displayCurrency: Currency,
        amountFormatter: AmountFormatter
    ) -> TokenManagementBalanceItem {
        let details = asset.asset
        let symbol = details.symbol
        let title = symbol
        let searchText = [details.symbol, details.name]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let trimmedImage = details.image.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageURL: URL? = {
            guard !trimmedImage.isEmpty else { return nil }
            return URL(string: trimmedImage)
        }()

        let verificationStatus = MultichainAssetListVerificationStatus(details: details)
        let subtitle: String
        let subtitleColor: TKColor
        if let verificationStatus {
            subtitle = verificationStatus.subtitle
            subtitleColor = verificationStatus.subtitleColor
        } else {
            subtitle = makeSubtitle(
                asset: asset,
                displayCurrency: displayCurrency,
                amountFormatter: amountFormatter
            )
            subtitleColor = .textSecondary
        }

        return TokenManagementBalanceItem(
            id: details.assetId,
            symbol: symbol,
            title: title,
            searchText: searchText,
            chainID: chain.rawValue,
            chainTag: AssetIdResolver.tag(
                for: details.assetId,
                multichainEnabled: true
            ),
            isHidden: asset.isHidden,
            avatarImageSource: AssetIdResolver.imageSource(
                for: details.assetId,
                imageUrl: imageURL,
                multichainEnabled: true
            ),
            subtitle: subtitle,
            subtitleColor: subtitleColor
        )
    }

    private static func makeSubtitle(
        asset: MultichainAsset,
        displayCurrency: Currency,
        amountFormatter: AmountFormatter
    ) -> String {
        let balance = multichainFormatter.decimalAmount(
            amount: asset.balance,
            fractionDigits: asset.asset.decimals
        )
        let fiatTotal = multichainFormatter.convertedAmount(
            for: asset,
            currency: displayCurrency
        ) ?? .zero

        let amountText = amountFormatter.format(
            decimal: balance,
            accessory: .tokenSymbol(asset.asset.symbol),
            style: .compact
        )

        guard fiatTotal > 0 else {
            return amountText
        }

        let convertedText = amountFormatter.format(
            decimal: fiatTotal,
            accessory: AmountAccessoryType(currency: displayCurrency),
            style: .compact
        )

        return "\(amountText) · \(convertedText)"
    }
}
