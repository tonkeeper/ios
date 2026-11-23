import CryptoKit
import Foundation
import TKLogging
import TonSwift

/// `perps_security` of the boot configuration as the backend serves it: a base64 JSON payload and an
/// ed25519 signature over the payload's decoded bytes by the key `key_version` names.
struct PerpsSecurityBlock: Codable, Equatable, Sendable {
    let payload: String
    let signature: String
    let keyVersion: Int

    enum CodingKeys: String, CodingKey {
        case payload
        case signature
        case keyVersion = "key_version"
    }
}

/// The contracts a perps deposit may name, as the backend signed them. Addresses are lowercase.
struct PerpsSecurityConfig: Sendable, Equatable {
    static let ethereum = "eth"

    let version: Int64
    let hermesDelegate: String
    let hermesDelegateChains: Set<String>
    let changePubKeyContract: String
    var relayLighterAccounts: Set<Int64> = []
    var relayTonDepositories: Set<String> = []
    var lighterGateway: String?
    var relayEVMDepositories: [String: Set<String>] = [:]
    var relayRouters: [String: [String: PerpsRelayRouter]] = [:]
    var relayTronDepositories: Set<String> = []
    var relayBitcoinDepositories: Set<String> = []
    var markets: [Int64: PerpsSignedMarket] = [:]

    var delegatesOnEthereum: Bool {
        hermesDelegateChains.contains(Self.ethereum)
    }

    func delegates(on chain: MultichainChain) -> Bool {
        hermesDelegateChains.contains(chain.rawValue)
    }

    var signedSymbols: [Int64: String]? {
        markets.isEmpty ? nil : markets.mapValues(\.symbol)
    }

    func marketId(symbol: String) -> Int64? {
        markets.values.first { $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame }?.marketId
    }
}

enum PerpsRelayRouter: String, Sendable, Equatable {
    case erc20Router = "erc20_router"
    case approvalProxy = "approval_proxy"
    case relayReceiver = "relay_receiver"
}

struct PerpsSignedMarket: Sendable, Equatable {
    static let signableIds: ClosedRange<Int64> = 0 ... Int64(Int16.max)

    let marketId: Int64
    let symbol: String
    let priceDecimals: Int32
    let sizeDecimals: Int32
    let quoteDecimals: Int32
    let minBaseAmount: String
    let minQuoteAmount: String
    let maxLeverage: Int32
}

enum PerpsSecurityConfigReader {
    private static let signatureLength = 64
    private static let maxMarketDecimals: Int32 = 18
    private static let maxLeverage: Int32 = 10000
    private static let maxAmountLength = 38

    static func read(_ block: PerpsSecurityBlock, trustedKeys: [Int: Data]) -> PerpsSecurityConfig? {
        guard let key = trustedKeys[block.keyVersion] else {
            return refuse("unknown key_version \(block.keyVersion)")
        }
        guard let payload = Data(base64Encoded: block.payload) else {
            return refuse("payload is not base64")
        }
        guard let signature = Data(base64Encoded: block.signature), signature.count == signatureLength else {
            return refuse("signature is not base64 of \(signatureLength) bytes")
        }
        guard let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: key),
              publicKey.isValidSignature(signature, for: payload)
        else {
            return refuse("signature does not match key_version \(block.keyVersion)")
        }
        return parse(payload)
    }

    private struct Payload: Decodable {
        struct Contracts: Decodable {
            let hermes_delegate: Delegate?
            let lighter_change_pub_key: Contract?
        }

        struct Delegate: Decodable {
            let address: String
            let chains: [String]
        }

        struct Contract: Decodable {
            let chain: String
            let address: String
        }

        let version: Int64
        let network: String
        let contracts: Contracts
    }

    private static func parse(_ payload: Data) -> PerpsSecurityConfig? {
        guard let config = try? JSONDecoder().decode(Payload.self, from: payload) else {
            return refuse("payload is not the config")
        }
        guard config.version >= 1 else {
            return refuse("version \(config.version)")
        }
        guard config.network == "mainnet" else {
            return refuse("not a mainnet config")
        }
        guard let delegate = config.contracts.hermes_delegate, let delegateAddress = evmAddress(delegate.address) else {
            return refuse("hermes_delegate")
        }
        guard let changePubKey = config.contracts.lighter_change_pub_key,
              changePubKey.chain == PerpsSecurityConfig.ethereum,
              let changePubKeyAddress = evmAddress(changePubKey.address)
        else {
            return refuse("lighter_change_pub_key")
        }
        let depositories = relayDepositories(payload)
        return PerpsSecurityConfig(
            version: config.version,
            hermesDelegate: delegateAddress,
            hermesDelegateChains: Set(delegate.chains),
            changePubKeyContract: changePubKeyAddress,
            relayLighterAccounts: relayLighterAccounts(depositories),
            relayTonDepositories: relayTonDepositories(depositories),
            lighterGateway: lighterGateway(payload),
            relayEVMDepositories: relayEVMDepositories(depositories),
            relayRouters: relayRouters(payload),
            relayTronDepositories: relayTronDepositories(depositories),
            relayBitcoinDepositories: relayBitcoinDepositories(depositories),
            markets: markets(payload)
        )
    }

    private struct Markets: Decodable {
        struct Entry: Decodable {
            let marketId: Int64?
            let symbol: String?
            let priceDecimals: Int32?
            let sizeDecimals: Int32?
            let quoteDecimals: Int32?
            let minBaseAmount: String?
            let minQuoteAmount: String?
            let maxLeverage: Int32?

            private enum CodingKeys: String, CodingKey {
                case marketId = "market_id"
                case symbol
                case priceDecimals = "price_decimals"
                case sizeDecimals = "size_decimals"
                case quoteDecimals = "quote_decimals"
                case minBaseAmount = "min_base_amount"
                case minQuoteAmount = "min_quote_amount"
                case maxLeverage = "max_leverage"
            }

            init(from decoder: Decoder) {
                let container = try? decoder.container(keyedBy: CodingKeys.self)
                marketId = try? container?.decode(Int64.self, forKey: .marketId)
                symbol = try? container?.decode(String.self, forKey: .symbol)
                priceDecimals = try? container?.decode(Int32.self, forKey: .priceDecimals)
                sizeDecimals = try? container?.decode(Int32.self, forKey: .sizeDecimals)
                quoteDecimals = try? container?.decode(Int32.self, forKey: .quoteDecimals)
                minBaseAmount = try? container?.decode(String.self, forKey: .minBaseAmount)
                minQuoteAmount = try? container?.decode(String.self, forKey: .minQuoteAmount)
                maxLeverage = try? container?.decode(Int32.self, forKey: .maxLeverage)
            }
        }

        let markets: [Entry]
    }

    private static func markets(_ payload: Data) -> [Int64: PerpsSignedMarket] {
        guard let entries = try? JSONDecoder().decode(Markets.self, from: payload).markets, !entries.isEmpty else {
            Log.perps.w("perps security config lists no markets")
            return [:]
        }
        let byMarketId = Dictionary(grouping: entries.compactMap(signedMarket), by: \.marketId)
        for (marketId, listed) in byMarketId where listed.count > 1 {
            Log.perps.w("perps security config lists market \(marketId) \(listed.count) times")
        }
        return byMarketId.compactMapValues { listed in listed.count == 1 ? listed.first : nil }
    }

    private static func signedMarket(_ entry: Markets.Entry) -> PerpsSignedMarket? {
        guard let marketId = entry.marketId, PerpsSignedMarket.signableIds.contains(marketId),
              let symbol = entry.symbol, !symbol.trimmingCharacters(in: .whitespaces).isEmpty,
              let priceDecimals = entry.priceDecimals, (0 ... maxMarketDecimals).contains(priceDecimals),
              let sizeDecimals = entry.sizeDecimals, (0 ... maxMarketDecimals).contains(sizeDecimals),
              let quoteDecimals = entry.quoteDecimals, (0 ... maxMarketDecimals).contains(quoteDecimals),
              let minBaseAmount = entry.minBaseAmount, isPlainAmount(minBaseAmount),
              let minQuoteAmount = entry.minQuoteAmount, isPlainAmount(minQuoteAmount),
              let leverage = entry.maxLeverage, (0 ... maxLeverage).contains(leverage)
        else {
            Log.perps.w("perps security config: unreadable market entry \(entry.marketId.map(String.init) ?? "?")")
            return nil
        }
        return PerpsSignedMarket(
            marketId: marketId,
            symbol: symbol,
            priceDecimals: priceDecimals,
            sizeDecimals: sizeDecimals,
            quoteDecimals: quoteDecimals,
            minBaseAmount: minBaseAmount,
            minQuoteAmount: minQuoteAmount,
            maxLeverage: leverage
        )
    }

    static func isPlainAmount(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return value.count <= maxAmountLength
            && (1 ... 2).contains(parts.count)
            && parts.allSatisfy { part in !part.isEmpty && part.allSatisfy { $0.isASCII && $0.isNumber } }
    }

    private struct GatewayContracts: Decodable {
        struct Contracts: Decodable {
            let lighter_gateway: Payload.Contract
        }

        let contracts: Contracts
    }

    private static func lighterGateway(_ payload: Data) -> String? {
        guard let gateway = try? JSONDecoder().decode(GatewayContracts.self, from: payload).contracts.lighter_gateway,
              gateway.chain == PerpsSecurityConfig.ethereum,
              let address = evmAddress(gateway.address)
        else {
            Log.perps.w("perps security config names no lighter_gateway")
            return nil
        }
        return address
    }

    private struct RelayDepositories: Decodable {
        struct Depository: Decodable {
            let chain: String?
            let address: String?

            private enum CodingKeys: String, CodingKey {
                case chain
                case address
            }

            init(from decoder: Decoder) {
                let container = try? decoder.container(keyedBy: CodingKeys.self)
                chain = try? container?.decode(String.self, forKey: .chain)
                address = try? container?.decode(String.self, forKey: .address)
            }
        }

        let relay_depositories: [Depository]
    }

    private static func relayDepositories(_ payload: Data) -> [RelayDepositories.Depository] {
        guard let depositories = try? JSONDecoder().decode(RelayDepositories.self, from: payload).relay_depositories else {
            Log.perps.w("perps security config has no relay_depositories")
            return []
        }
        return depositories
    }

    private static func relayLighterAccounts(_ depositories: [RelayDepositories.Depository]) -> Set<Int64> {
        Set(depositories.compactMap { depository in
            guard depository.chain == "lighter", let address = depository.address,
                  address.first != "0", address.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let index = Int64(address)
            else { return nil }
            return index
        })
    }

    private static func relayTonDepositories(_ depositories: [RelayDepositories.Depository]) -> Set<String> {
        let addresses = Set(depositories.compactMap { depository -> String? in
            guard depository.chain == "ton", let address = depository.address else { return nil }
            return try? TonSwift.Address.parse(address).toRaw()
        })
        if addresses.isEmpty {
            Log.perps.w("perps security config names no Relay depository on TON")
        }
        return addresses
    }

    private static func relayEVMDepositories(_ depositories: [RelayDepositories.Depository]) -> [String: Set<String>] {
        var byChain = [String: Set<String>]()
        for depository in depositories {
            guard let chain = depository.chain, MultichainChain(rawValue: chain)?.isEVM == true,
                  let address = depository.address.flatMap(evmAddress)
            else { continue }
            byChain[chain, default: []].insert(address)
        }
        return byChain
    }

    private struct RelayRouters: Decodable {
        struct Router: Decodable {
            let chain: String?
            let address: String?
            let type: String?

            private enum CodingKeys: String, CodingKey {
                case chain
                case address
                case type
            }

            init(from decoder: Decoder) {
                let container = try? decoder.container(keyedBy: CodingKeys.self)
                chain = try? container?.decode(String.self, forKey: .chain)
                address = try? container?.decode(String.self, forKey: .address)
                type = try? container?.decode(String.self, forKey: .type)
            }
        }

        let relay_routers: [Router]
    }

    private static func relayRouters(_ payload: Data) -> [String: [String: PerpsRelayRouter]] {
        guard let routers = try? JSONDecoder().decode(RelayRouters.self, from: payload).relay_routers, !routers.isEmpty else {
            Log.perps.w("perps security config names no Relay router")
            return [:]
        }
        var roles = [String: [String: Set<PerpsRelayRouter>]]()
        for router in routers {
            guard let chain = router.chain, MultichainChain(rawValue: chain)?.isEVM == true,
                  let address = router.address.flatMap(evmAddress),
                  let role = router.type.flatMap(PerpsRelayRouter.init(rawValue:))
            else {
                Log.perps.w("perps security config: unreadable Relay router entry on \(router.chain ?? "?")")
                continue
            }
            roles[chain, default: [:]][address, default: []].insert(role)
        }
        return roles.mapValues { byAddress in
            byAddress.compactMapValues { listed in
                guard listed.count == 1 else {
                    Log.perps.w("perps security config lists one Relay router under \(listed.count) roles")
                    return nil
                }
                return listed.first
            }
        }.filter { !$0.value.isEmpty }
    }

    private static func relayTronDepositories(_ depositories: [RelayDepositories.Depository]) -> Set<String> {
        Set(depositories.compactMap { depository -> String? in
            guard depository.chain == MultichainChain.tron.rawValue, let address = depository.address,
                  PerpsFundingAssetId.isTronAddress(address)
            else { return nil }
            return address
        })
    }

    private static func relayBitcoinDepositories(_ depositories: [RelayDepositories.Depository]) -> Set<String> {
        let addresses = Set(depositories.compactMap { depository -> String? in
            guard depository.chain == MultichainChain.btc.rawValue, let address = depository.address else { return nil }
            return PerpsFundingAssetId.bitcoinAddress(address)
        })
        if addresses.isEmpty {
            Log.perps.w("perps security config names no Relay depository on Bitcoin")
        }
        return addresses
    }

    private static func evmAddress(_ value: String) -> String? {
        guard value.hasPrefix("0x"), PerpsKeyRegistrationPreview.isHex(String(value.dropFirst(2)), length: 40) else {
            return nil
        }
        return value.lowercased()
    }

    private static func refuse(_ reason: String) -> PerpsSecurityConfig? {
        Log.perps.w("perps security config refused: \(reason)")
        return nil
    }
}

protocol PerpsSecurityConfigStore: Sendable {
    func keptBlock() -> PerpsSecurityBlock?
    func keep(_ block: PerpsSecurityBlock)
}

struct PerpsSecurityConfigDefaultsStore: PerpsSecurityConfigStore {
    private static let key = "perps_security_verified_block"

    func keptBlock() -> PerpsSecurityBlock? {
        guard let text = UserDefaults.standard.string(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(PerpsSecurityBlock.self, from: Data(text.utf8))
    }

    func keep(_ block: PerpsSecurityBlock) {
        guard let data = try? JSONEncoder().encode(block) else { return }
        UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: Self.key)
    }
}

/// The last block that verified is kept and verified again whenever the kept or the served block changes,
/// so a served block that fails its signature, or is older than the kept one, leaves the kept one in force.
actor PerpsSecurityConfigRepository {
    // swiftlint:disable:next force_unwrapping
    static let trustedKeys: [Int: Data] = [1: Data(base64Encoded: "TSVyO+TGwwp9YCd5J25nUplZ66onplW1fJqtovYyqPc=")!]

    private let servedBlock: @Sendable () async -> PerpsSecurityBlock?
    private let downloadedBlock: @Sendable () async -> PerpsSecurityBlock?
    private let currentBlock: @Sendable () -> PerpsSecurityBlock?
    private let store: any PerpsSecurityConfigStore
    private let trustedKeys: [Int: Data]
    private var lastRead: VerifiedRead?

    static func live(configuration: Configuration) -> PerpsSecurityConfigRepository {
        PerpsSecurityConfigRepository(
            servedBlock: { [configuration] in
                if let served = configuration.value(\.perpsSecurity) {
                    return served
                }
                return await configuration.loadConfigurations().mainnet.perpsSecurity
            },
            downloadedBlock: { [configuration] in await configuration.loadConfigurations().mainnet.perpsSecurity },
            currentBlock: { [configuration] in configuration.value(\.perpsSecurity) }
        )
    }

    init(
        servedBlock: @escaping @Sendable () async -> PerpsSecurityBlock?,
        downloadedBlock: (@Sendable () async -> PerpsSecurityBlock?)? = nil,
        currentBlock: @escaping @Sendable () -> PerpsSecurityBlock? = { nil },
        store: any PerpsSecurityConfigStore = PerpsSecurityConfigDefaultsStore(),
        trustedKeys: [Int: Data] = PerpsSecurityConfigRepository.trustedKeys
    ) {
        self.servedBlock = servedBlock
        self.downloadedBlock = downloadedBlock ?? servedBlock
        self.currentBlock = currentBlock
        self.store = store
        self.trustedKeys = trustedKeys
    }

    func verified() async -> PerpsSecurityConfig? {
        await verified(served: servedBlock())
    }

    nonisolated func verifiedNow() -> PerpsSecurityConfig? {
        read(served: currentBlock(), keptBlock: store.keptBlock())
    }

    func verifiedAfterDownload() async -> PerpsSecurityConfig? {
        await verified(served: downloadedBlock())
    }

    private func verified(served: PerpsSecurityBlock?) -> PerpsSecurityConfig? {
        let keptBlock = store.keptBlock()
        if let lastRead, lastRead.keptBlock == keptBlock, lastRead.servedBlock == served {
            return lastRead.config
        }
        let config = read(served: served, keptBlock: keptBlock)
        lastRead = VerifiedRead(keptBlock: store.keptBlock(), servedBlock: served, config: config)
        return config
    }

    private nonisolated func read(served: PerpsSecurityBlock?, keptBlock: PerpsSecurityBlock?) -> PerpsSecurityConfig? {
        let kept = keptBlock.flatMap { PerpsSecurityConfigReader.read($0, trustedKeys: trustedKeys) }
        guard let served, served != keptBlock,
              let fresh = PerpsSecurityConfigReader.read(served, trustedKeys: trustedKeys)
        else {
            return kept
        }
        if let kept, fresh.version < kept.version {
            Log.perps.w("perps security config v\(fresh.version) is older than the kept v\(kept.version)")
            return kept
        }
        store.keep(served)
        return fresh
    }
}

private struct VerifiedRead {
    let keptBlock: PerpsSecurityBlock?
    let servedBlock: PerpsSecurityBlock?
    let config: PerpsSecurityConfig?
}
