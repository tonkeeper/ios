import BigInt
import Foundation
import KeeperCore
import TKLogging
import TonSwift

struct MultichainSwapInitialAssets {
    let sendAsset: MultichainAsset
    let receiveAsset: MultichainAsset
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
    private let assetDetailsService: TradingAssetDetailsService
    private let currencyStore: CurrencyStore
    private let initialSelection: MultichainSwapInitialAssetSelection?

    init(
        multichainState: MultichainWalletState,
        multichainService: MultichainService,
        multichainSwapService: MultichainSwapService,
        assetDetailsService: TradingAssetDetailsService,
        currencyStore: CurrencyStore,
        initialSelection: MultichainSwapInitialAssetSelection? = nil
    ) {
        self.multichainState = multichainState
        self.multichainService = multichainService
        self.multichainSwapService = multichainSwapService
        self.assetDetailsService = assetDetailsService
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
            showAll: nil,
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
            slippage: config.slippage,
            usdFiatRate: MultichainSwapFiatRateResolver(displayCurrency: currency)
                .walletDerivedUsdFiatRate(walletAssets: walletAssets),
            hasUnavailableInitialSelection: resolvedSelection.hasUnavailableSelection
        )
    }
}

private extension DefaultMultichainSwapDefaultAssetsService {
    struct ResolvedInitialSelection {
        let fromAssetId: String?
        let toAssetId: String?
        let hasUnavailableSelection: Bool
    }

    func resolvedInitialSelection() async throws -> ResolvedInitialSelection {
        guard let initialSelection else {
            return ResolvedInitialSelection(
                fromAssetId: nil,
                toAssetId: nil,
                hasUnavailableSelection: false
            )
        }
        async let resolvedFromAsset = configAsset(for: initialSelection.sendAssetId)
        async let resolvedToAsset = configAsset(for: initialSelection.receiveAssetId)
        let (fromAssetId, toAssetId) = try await(resolvedFromAsset, resolvedToAsset)
        let hasUnavailableSelection = isUnavailable(requested: initialSelection.sendAssetId, resolved: fromAssetId)
            || isUnavailable(requested: initialSelection.receiveAssetId, resolved: toAssetId)
        return ResolvedInitialSelection(
            fromAssetId: fromAssetId,
            toAssetId: fromAssetId == toAssetId ? nil : toAssetId,
            hasUnavailableSelection: hasUnavailableSelection
        )
    }

    /// Only catalog-shaped ids are worth reporting: legacy symbol deeplinks (`ft=USDT`) never
    /// resolve on multichain wallets and are expected to fall back silently.
    func isUnavailable(requested: String?, resolved: String?) -> Bool {
        MultichainSwapInitialAssetSelection.isCatalogAssetId(requested) && resolved == nil
    }

    func configAsset(for value: String?) async throws -> String? {
        switch MultichainSwapInitialAssetSelection.catalogAssetReference(value) {
        case .none:
            return nil
        case let .assetId(assetId):
            return try await swappableAssetId(assetId)
        case let .token(chainId, standard, address):
            return try await resolvedTokenAsset(
                chainId: chainId,
                standard: standard,
                address: address
            )
        case let .chainScope(chainId, .none):
            return try await swappableAssetId(
                "\(chainId)/\(MultichainSwapInitialAssetSelection.nativeAssetIdSuffix)"
            )
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
            return availableAssetId(asset.assetId)
        }
    }

    func resolvedTokenAsset(
        chainId: String,
        standard: String,
        address: String
    ) async throws -> String? {
        let address = MultichainSwapInitialAssetSelection.normalizedAssetAddress(address, chainId: chainId)
        if standard != "token" {
            return try await swappableAssetId(
                "\(chainId)/\(standard)/\(address)"
            )
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
        return availableAssetId(asset.assetId)
    }

    func chainCatalogAssets(chainId: String) async throws -> [MultichainSwapAsset] {
        try await multichainSwapService.listCrossSwapAssets(
            query: MultichainSwapAssetsQuery(chain: chainId)
        )
    }

    func swappableAssetId(_ assetId: String) async throws -> String? {
        let details: TradingAssetDetails
        if let cached = await assetDetailsService.assetDetails(for: assetId) {
            details = cached
        } else {
            do {
                details = try await assetDetailsService.loadAssetDetails(id: assetId)
            } catch .notFound {
                return nil
            }
        }
        guard details.capabilities.supportsSwap else {
            return nil
        }
        return availableAssetId(details.assetInfo.assetId)
    }

    func availableAssetId(_ assetId: String) -> String? {
        guard
            let chain = MultichainChain(assetId: assetId),
            multichainState.addresses.contains(where: { $0.chain == chain })
        else {
            Log.multichainSwap.w(
                "initial selection asset chain is unavailable for this wallet",
                extraInfo: [
                    "selectedAsset": assetId,
                    "addressChainCount": "\(multichainState.addresses.count)",
                ]
            )
            return nil
        }
        return assetId
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
                diff7d: [:]
            )
        } else {
            price = MultichainAssetPrice(
                prices: [:],
                diff24h: [:],
                diff7d: [:]
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
