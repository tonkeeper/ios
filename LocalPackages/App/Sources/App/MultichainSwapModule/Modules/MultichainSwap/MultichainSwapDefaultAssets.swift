import BigInt
import Foundation
import KeeperCore
import TKLogging
import TonSwift

struct MultichainSwapInitialAssets {
    let sendAsset: MultichainAsset
    let receiveAsset: MultichainAsset
    let catalog: [String: MultichainSwapAsset]
    let slippage: MultichainSwapSlippage?
    var usdFiatRate: Decimal? = nil
    var hasUnavailableInitialSelection: Bool = false
}

public struct MultichainSwapInitialAssetSelection: Equatable, Sendable {
    public enum Side: Equatable, Sendable {
        case send
        case receive
    }

    public let sendAssetId: String?
    public let receiveAssetId: String?

    public init(sendAssetId: String?, receiveAssetId: String?) {
        self.sendAssetId = sendAssetId
        self.receiveAssetId = receiveAssetId
    }

    public init(assetId: String, side: Side) {
        switch side {
        case .send:
            self.init(sendAssetId: assetId, receiveAssetId: nil)
        case .receive:
            self.init(sendAssetId: nil, receiveAssetId: assetId)
        }
    }
}

enum MultichainSwapCatalogAssetReference: Equatable {
    case assetId(String)
    case token(chainId: String, standard: String, address: String)
    case chainScope(chainId: String, standard: String?)
}

extension MultichainSwapInitialAssetSelection {
    static func catalogAssetReference(_ value: String?) -> MultichainSwapCatalogAssetReference? {
        guard let value else { return nil }
        let segments = value.split(separator: "/", omittingEmptySubsequences: false)
        guard (2 ... 4).contains(segments.count) else { return nil }
        let isSlug: (Substring) -> Bool = { segment in
            !segment.isEmpty && segment.allSatisfy { character in
                (character.isLetter && character.isLowercase) || character.isNumber || character == "-"
            }
        }
        guard isSlug(segments[0]), isSlug(segments[1]) else { return nil }
        let chainId = "\(segments[0])/\(segments[1])"

        switch segments.count {
        case 2:
            return .chainScope(chainId: chainId, standard: nil)
        case 3 where segments[2] == Self.nativeAssetIdSuffix:
            return .assetId(value)
        case 3 where isSlug(segments[2]):
            return .chainScope(chainId: chainId, standard: String(segments[2]))
        case 4 where isSlug(segments[2]) && !segments[3].isEmpty:
            return .token(
                chainId: chainId,
                standard: String(segments[2]),
                address: String(segments[3])
            )
        default:
            return nil
        }
    }

    static func isCatalogAssetId(_ value: String?) -> Bool {
        catalogAssetReference(value) != nil
    }

    /// Catalog asset ids keep EVM addresses lowercased and TON addresses raw, while a deeplink
    /// may carry a checksummed EVM address or a friendly TON one.
    static func normalizedAssetAddress(_ address: String, chainId: String) -> String {
        if address.lowercased().hasPrefix("0x") {
            return address.lowercased()
        }
        if chainId.hasPrefix("ton/"), let parsedAddress = try? Address.parse(address) {
            return parsedAddress.toRaw()
        }
        return address
    }

    static func tokenAddress(inAssetId assetId: String) -> String? {
        let segments = assetId.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.count == 4 else { return nil }
        return String(segments[3])
    }

    static let nativeAssetIdSuffix = "coin"

    init?(deeplinkSendAssetId: String?, deeplinkReceiveAssetId: String?) {
        let sendAssetId = Self.isCatalogAssetId(deeplinkSendAssetId) ? deeplinkSendAssetId : nil
        let receiveAssetId = Self.isCatalogAssetId(deeplinkReceiveAssetId) ? deeplinkReceiveAssetId : nil
        guard sendAssetId != nil || receiveAssetId != nil else { return nil }
        self.init(sendAssetId: sendAssetId, receiveAssetId: receiveAssetId)
    }
}

protocol MultichainSwapDefaultAssetsService {
    func load() async throws -> MultichainSwapInitialAssets
}

struct DefaultMultichainSwapDefaultAssetsService: MultichainSwapDefaultAssetsService {
    private let multichainState: MultichainWalletState
    private let multichainService: MultichainService
    private let multichainSwapService: MultichainSwapService
    private let currencyStore: CurrencyStore
    private let initialSelection: MultichainSwapInitialAssetSelection?

    init(
        multichainState: MultichainWalletState,
        multichainService: MultichainService,
        multichainSwapService: MultichainSwapService,
        currencyStore: CurrencyStore,
        initialSelection: MultichainSwapInitialAssetSelection? = nil
    ) {
        self.multichainState = multichainState
        self.multichainService = multichainService
        self.multichainSwapService = multichainSwapService
        self.currencyStore = currencyStore
        self.initialSelection = initialSelection
    }

    func load() async throws -> MultichainSwapInitialAssets {
        Log.multichainSwap.i(
            "initial asset loading started",
            extraInfo: ["addressChainCount": "\(multichainState.addresses.count)"]
        )
        let currency = currencyStore.state
        async let walletAssetsTask = multichainService.getAllWalletAssets(
            state: multichainState,
            currencies: requestedCurrencyCodes(for: currency),
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: false,
            hideDust: nil
        ).assets
        let resolvedSelection = try await resolvedInitialSelection()
        let config: MultichainSwapConfig
        do {
            config = try await multichainSwapService.getCrossSwapConfig(
                walletId: multichainState.walletId,
                fromAssetId: resolvedSelection.fromAssetId,
                toAssetId: resolvedSelection.toAssetId
            )
        } catch {
            Log.multichainSwap.w(
                "initial swap configuration loading failed",
                error: error
            )
            throw error
        }
        let defaultPair = config.defaultPair

        let walletAssets: [MultichainAsset]
        do {
            walletAssets = try await walletAssetsTask
        } catch {
            Log.multichainSwap.w(
                "initial asset loading failed",
                error: error
            )
            throw error
        }
        let availableChains = Set(multichainState.addresses.map(\.chain))
        Log.multichainSwap.i(
            "initial asset sources loaded",
            extraInfo: [
                "walletAssetCount": "\(walletAssets.count)",
                "availableChainCount": "\(availableChains.count)",
            ]
        )

        let walletAssetsById = Dictionary(
            walletAssets.map { ($0.asset.assetId, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        guard let sourceCatalogAsset = defaultPair.sourceAsset else {
            Log.multichainSwap.w(
                "initial source catalog asset is missing in the swap configuration",
                extraInfo: [
                    "availableChainCount": "\(availableChains.count)",
                ]
            )
            throw MultichainSwapInitialAssetsError.missingSourceAsset
        }

        guard let destinationCatalogAsset = defaultPair.destinationAsset else {
            Log.multichainSwap.w(
                "initial destination catalog asset is missing in the swap configuration",
                extraInfo: [
                    "sourceAsset": sourceCatalogAsset.assetId,
                ]
            )
            throw MultichainSwapInitialAssetsError.missingDestinationAsset
        }
        let catalog = Dictionary(
            [sourceCatalogAsset, destinationCatalogAsset].map { ($0.assetId, $0) },
            uniquingKeysWith: { current, _ in current }
        )

        let sourceAsset = sourceCatalogAsset.multichainAsset(
            walletAsset: walletAssetsById[sourceCatalogAsset.assetId]
        )
        let destinationAsset = destinationCatalogAsset.multichainAsset(
            walletAsset: walletAssetsById[destinationCatalogAsset.assetId]
        )
        Log.multichainSwap.i(
            "initial assets selected",
            extraInfo: [
                "sourceAsset": sourceAsset.asset.assetId,
                "destinationAsset": destinationAsset.asset.assetId,
                "sourceBalance": sourceAsset.balance.description,
            ]
        )
        return MultichainSwapInitialAssets(
            sendAsset: sourceAsset,
            receiveAsset: destinationAsset,
            catalog: catalog,
            slippage: config.slippage,
            usdFiatRate: MultichainSwapFiatRateResolver(displayCurrency: currency)
                .walletDerivedUsdFiatRate(walletAssets: walletAssets),
            hasUnavailableInitialSelection: resolvedSelection.hasUnavailableSelection
        )
    }
}

private extension DefaultMultichainSwapDefaultAssetsService {
    struct ResolvedInitialSelection {
        let fromAsset: MultichainSwapAsset?
        let toAsset: MultichainSwapAsset?
        let hasUnavailableSelection: Bool

        var fromAssetId: String? {
            fromAsset?.assetId
        }

        var toAssetId: String? {
            toAsset?.assetId
        }
    }

    func resolvedInitialSelection() async throws -> ResolvedInitialSelection {
        guard let initialSelection else {
            return ResolvedInitialSelection(
                fromAsset: nil,
                toAsset: nil,
                hasUnavailableSelection: false
            )
        }
        async let resolvedFromAsset = configAsset(for: initialSelection.sendAssetId)
        async let resolvedToAsset = configAsset(for: initialSelection.receiveAssetId)
        let (fromAsset, toAsset) = try await(resolvedFromAsset, resolvedToAsset)
        let hasUnavailableSelection = isUnavailable(requested: initialSelection.sendAssetId, resolved: fromAsset)
            || isUnavailable(requested: initialSelection.receiveAssetId, resolved: toAsset)
        return ResolvedInitialSelection(
            fromAsset: fromAsset,
            toAsset: fromAsset?.assetId == toAsset?.assetId ? nil : toAsset,
            hasUnavailableSelection: hasUnavailableSelection
        )
    }

    /// Only catalog-shaped ids are worth reporting: legacy symbol deeplinks (`ft=USDT`) never
    /// resolve on multichain wallets and are expected to fall back silently.
    func isUnavailable(requested: String?, resolved: MultichainSwapAsset?) -> Bool {
        MultichainSwapInitialAssetSelection.isCatalogAssetId(requested) && resolved == nil
    }

    func configAsset(for value: String?) async throws -> MultichainSwapAsset? {
        switch MultichainSwapInitialAssetSelection.catalogAssetReference(value) {
        case .none:
            return nil
        case let .assetId(assetId):
            return try await catalogAsset(assetId: assetId).flatMap(availableCatalogAsset)
        case let .token(chainId, standard, address):
            return try await resolvedTokenAsset(
                chainId: chainId,
                standard: standard,
                address: address
            )
        case let .chainScope(chainId, .none):
            return try await catalogAsset(
                assetId: "\(chainId)/\(MultichainSwapInitialAssetSelection.nativeAssetIdSuffix)"
            ).flatMap(availableCatalogAsset)
        case let .chainScope(chainId, .some(standard)):
            let assets = try await chainCatalogAssets(chainId: chainId)
            let matches = assets.filter { $0.assetId.hasPrefix("\(chainId)/\(standard)/") }
            guard matches.count == 1, let asset = matches.first else {
                Log.multichainSwap.w(
                    "initial selection chain scope is not a single asset",
                    extraInfo: [
                        "chain": chainId,
                        "standard": standard,
                        "matchCount": "\(matches.count)",
                        "chainAssetCount": "\(assets.count)",
                    ]
                )
                return nil
            }
            return availableCatalogAsset(asset)
        }
    }

    func resolvedTokenAsset(
        chainId: String,
        standard: String,
        address: String
    ) async throws -> MultichainSwapAsset? {
        let address = MultichainSwapInitialAssetSelection.normalizedAssetAddress(address, chainId: chainId)
        if standard != "token" {
            return try await catalogAsset(
                assetId: "\(chainId)/\(standard)/\(address)"
            ).flatMap(availableCatalogAsset)
        }
        let assets = try await chainCatalogAssets(chainId: chainId)
        let matches = assets.filter { asset in
            guard let catalogAddress = MultichainSwapInitialAssetSelection.tokenAddress(inAssetId: asset.assetId) else {
                return false
            }
            return MultichainSwapInitialAssetSelection.normalizedAssetAddress(
                catalogAddress,
                chainId: chainId
            ) == address
        }
        guard matches.count == 1, let asset = matches.first else {
            Log.multichainSwap.w(
                "initial selection token address is not a single asset",
                extraInfo: [
                    "chain": chainId,
                    "standard": standard,
                    "matchCount": "\(matches.count)",
                    "chainAssetCount": "\(assets.count)",
                ]
            )
            return nil
        }
        return availableCatalogAsset(asset)
    }

    func chainCatalogAssets(chainId: String) async throws -> [MultichainSwapAsset] {
        try await multichainSwapService.listCrossSwapAssets(
            query: MultichainSwapAssetsQuery(chain: chainId)
        )
    }

    func catalogAsset(assetId: String) async throws -> MultichainSwapAsset? {
        do {
            return try await multichainSwapService.getCrossSwapAsset(assetId: assetId)
        } catch MultichainSwapAPIError.notFound {
            return nil
        }
    }

    func availableCatalogAsset(_ asset: MultichainSwapAsset) -> MultichainSwapAsset? {
        guard
            let chain = MultichainChain(assetIdChain: asset.chainIdChain),
            multichainState.addresses.contains(where: { $0.chain == chain })
        else {
            Log.multichainSwap.w(
                "initial selection asset chain is unavailable for this wallet",
                extraInfo: [
                    "selectedAsset": asset.assetId,
                    "chain": asset.chainIdChain,
                    "addressChainCount": "\(multichainState.addresses.count)",
                ]
            )
            return nil
        }
        return asset
    }
}

enum MultichainSwapInitialAssetsError: LoggableError {
    case missingSourceAsset
    case missingDestinationAsset
}

extension MultichainSwapInitialAssetsError {
    var logDescription: String {
        let caseName: String
        switch self {
        case .missingSourceAsset:
            caseName = "missingSourceAsset"
        case .missingDestinationAsset:
            caseName = "missingDestinationAsset"
        }
        return "type=MultichainSwapInitialAssetsError, case=\(caseName)"
    }
}

extension MultichainSwapAsset {
    var chainIdChain: String {
        assetId.split(separator: "/").first.map(String.init) ?? ""
    }

    func multichainAsset(
        walletAsset: MultichainAsset?
    ) -> MultichainAsset {
        if let walletAsset {
            return walletAsset
        }

        let price: MultichainAssetPrice
        if let usdPrice {
            price = MultichainAssetPrice(
                prices: [Currency.USD.code.lowercased(): usdPrice],
                diff24h: [:],
                diff7d: [:],
                diff30d: [:]
            )
        } else {
            price = MultichainAssetPrice(
                prices: [:],
                diff24h: [:],
                diff7d: [:],
                diff30d: [:]
            )
        }

        return MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: name,
                symbol: symbol,
                decimals: decimals,
                image: image ?? ""
            ),
            price: price,
            balance: .zero
        )
    }
}

func requestedCurrencyCodes(for currency: Currency) -> [String] {
    var codes = [currency.code.lowercased()]
    if currency != .defaultCurrency {
        codes.append(Currency.defaultCurrency.code.lowercased())
    }
    return codes
}
