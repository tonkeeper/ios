import BigInt
import Foundation
import TKLogging
import TonAPI
import TonSwift
import TronSwift

public protocol WalletMigrationService {
    func prepareMigration(
        from sourceWallet: Wallet,
        to destinationWallet: Wallet,
        currency: Currency
    ) async throws -> WalletMigrationPrepareResult

    func prepareTronMigration(
        from sourceWallet: Wallet,
        to destinationWallet: Wallet
    ) async throws -> WalletMigrationTronPrepareResult?

    func availableBatteryCharges(wallet: Wallet) async -> Int?

    func getMigrationWallets(
        wallets: [Wallet],
        currency: Currency
    ) async throws -> [WalletMigrationWalletValue]
}

final class WalletMigrationServiceImplementation: WalletMigrationService {
    private struct MigrationRates {
        let ton: Rates.Rate?
        let usdt: Rates.Rate?
        let trx: Rates.Rate?
    }

    private let apiProvider: APIProvider
    private let configuration: Configuration
    private let tonBalanceService: TonBalanceService
    private let tronBalanceService: TronBalanceService
    private let tronUsdtApi: TronUSDTAPI
    private let ratesService: RatesService
    private let tonRatesStore: TonRatesStore
    private let batteryService: BatteryService
    private let tronBalanceCache = TronMigrationBalanceCache(ttl: 60)

    init(
        apiProvider: APIProvider,
        configuration: Configuration,
        tonBalanceService: TonBalanceService,
        tronBalanceService: TronBalanceService,
        tronUsdtApi: TronUSDTAPI,
        ratesService: RatesService,
        tonRatesStore: TonRatesStore,
        batteryService: BatteryService
    ) {
        self.apiProvider = apiProvider
        self.configuration = configuration
        self.tonBalanceService = tonBalanceService
        self.tronBalanceService = tronBalanceService
        self.tronUsdtApi = tronUsdtApi
        self.ratesService = ratesService
        self.tonRatesStore = tonRatesStore
        self.batteryService = batteryService
    }

    func prepareMigration(
        from sourceWallet: Wallet,
        to destinationWallet: Wallet,
        currency: Currency
    ) async throws -> WalletMigrationPrepareResult {
        let fromAddress = try sourceWallet.tonMigrationAddress()
        let toAddress = try destinationWallet.tonMigrationAddress()
        let publicKey = try sourceWallet.tonMigrationPublicKey()
        let api = apiProvider.api(sourceWallet.network)

        async let batteryPrep = prepareBatteryTransactions(
            api: api,
            from: fromAddress,
            to: toAddress,
            currency: currency,
            publicKey: publicKey,
            wallet: sourceWallet
        )

        let selfResponse: MigrationPrepareResponseBody
        do {
            selfResponse = try await api.prepareMigration(
                from: fromAddress,
                to: toAddress,
                currency: currency,
                publicKey: publicKey,
                gasPayer: .self
            )
        } catch {
            if let migrationError = WalletMigrationError(apiError: error) {
                throw migrationError
            }
            throw error
        }

        let selfTransactions = try mapTransactions(selfResponse.transactions)
        async let availableTonNano = loadAvailableTonNano(wallet: sourceWallet)

        let batteryTransactions = await batteryPrep
        let hasSponsoredBatteryPath = batteryTransactions?.contains(where: \.sponsored) == true
        let batteryTotalFees = WalletMigrationPrepareResult.batteryChargeBasisNano(
            from: batteryTransactions
        )
        let selfTotalFees = selfTransactions.reduce(into: UInt64.zero) { $0 += $1.totalFees }
        let insufficientTonDetails = selfResponse.details
        let requiredTonNano = insufficientTonDetails.map { UInt64(max($0._required, 0)) }
        let feeResolver = WalletMigrationTonFeeOptionsResolver(configuration: configuration)
        let availableFeeMethods = await feeResolver.resolve(
            selfTotalFees: selfTotalFees,
            batteryTotalFees: batteryTotalFees,
            hasSponsoredBatteryPath: hasSponsoredBatteryPath,
            allowBatteryQuoteWithoutSponsoredPath: Self.allowsBatteryQuoteWithoutSponsoredPath(
                wallet: sourceWallet
            ),
            wallet: sourceWallet
        )
        let resolvedAvailableTonNano = await availableTonNano
            ?? insufficientTonDetails.map { UInt64(max($0.available, 0)) }

        return WalletMigrationPrepareResult(
            from: selfResponse.from,
            to: selfResponse.to,
            walletVersion: selfResponse.walletVersion,
            transactions: selfTransactions,
            batteryTransactions: hasSponsoredBatteryPath ? batteryTransactions : nil,
            availableFeeMethods: availableFeeMethods,
            availableTonNano: resolvedAvailableTonNano,
            requiredTonNano: requiredTonNano
        )
    }

    private static func allowsBatteryQuoteWithoutSponsoredPath(wallet: Wallet) -> Bool {
        switch try? wallet.contractVersion {
        case .v3R1, .v3R2, .v4R1, .v4R2:
            return true
        default:
            return false
        }
    }

    private func prepareBatteryTransactions(
        api: API,
        from: String,
        to: String,
        currency: Currency,
        publicKey: String,
        wallet: Wallet
    ) async -> [WalletMigrationPreparedTransaction]? {
        guard wallet.isBatteryEnable else { return nil }
        let isBatteryEnable = await configuration.isBatteryEnable(network: wallet.network)
        guard isBatteryEnable else { return nil }

        do {
            async let batteryConfig = batteryService.loadBatteryConfig(wallet: wallet)
            let response = try await api.prepareMigration(
                from: from,
                to: to,
                currency: currency,
                publicKey: publicKey,
                gasPayer: .battery
            )
            let resolvedBatteryConfig = try await batteryConfig
            let excessAddress = try resolvedBatteryConfig.excessAddress
            let transactions = try mapTransactions(
                response.transactions,
                sponsoredExcessAddress: excessAddress
            )
            guard transactions.contains(where: \.sponsored) else { return nil }
            return transactions
        } catch {
            return nil
        }
    }

    private func mapTransactions(
        _ transactions: [MigrationTransactionBody],
        sponsoredExcessAddress: TonSwift.Address? = nil
    ) throws -> [WalletMigrationPreparedTransaction] {
        try transactions.map { transaction in
            let event = try AccountEvent(accountEvent: transaction.emulation.event)
            let messages = try transaction.messages.map { message in
                let boc: String
                if transaction.isSponsored, let sponsoredExcessAddress {
                    let relaxed = try MessageRelaxed.loadFrom(
                        slice: Cell.fromBase64(src: message.boc.fixBase64()).beginParse()
                    )
                    boc = try TransferPayloadExcessAddressRewriter
                        .rewrite(message: relaxed, excessAddress: sponsoredExcessAddress)
                        .toBoc()
                        .base64EncodedString()
                } else {
                    boc = message.boc
                }
                return WalletMigrationOutMessage(boc: boc, mode: message.mode)
            }
            return WalletMigrationPreparedTransaction(
                seqno: transaction.seqno,
                boc: transaction.boc,
                stateInit: transaction.stateInit,
                messages: messages,
                event: event,
                totalFees: transaction.resolvedGasSpentNano,
                totalEquivalent: transaction.emulation.risk.totalEquivalent.map(Double.init),
                sponsored: transaction.isSponsored
            )
        }
    }

    private func loadAvailableTonNano(wallet: Wallet) async -> UInt64? {
        guard let tonBalance = try? await tonBalanceService.loadBalance(wallet: wallet) else {
            return nil
        }
        return UInt64(max(tonBalance.amount, 0))
    }

    func availableBatteryCharges(wallet: Wallet) async -> Int? {
        guard let batteryBalance = try? await batteryService.loadBatteryBalance(wallet: wallet) else {
            return nil
        }
        return BatteryCalculation(configuration: configuration)
            .calculateAvailableCharges(balance: batteryBalance)
    }

    func prepareTronMigration(
        from sourceWallet: Wallet,
        to destinationWallet: Wallet
    ) async throws -> WalletMigrationTronPrepareResult? {
        guard sourceWallet.tron != nil else {
            return nil
        }

        let sourceAddress = try sourceWallet.tronMigrationAddress()
        let destinationAddress = try destinationWallet.tronMigrationAddress()

        let balance = try await tronBalanceService.loadBalance(address: sourceAddress)

        let hasUSDT = balance.amount > 0
        let hasReportedTRXBalance = balance.trxAmount > 0
        guard hasUSDT || hasReportedTRXBalance else {
            return nil
        }

        let isActivated = if hasUSDT {
            try await tronUsdtApi.isAccountActivated(address: sourceAddress)
        } else {
            true
        }
        let availableTRXSun = isActivated ? balance.trxAmount : 0
        let hasTRXBalance = availableTRXSun > 0

        var usdtEstimate: TronTransferFeeEstimate?
        if hasUSDT {
            let method = TransferMethod(
                to: destinationAddress,
                amount: balance.amount
            )
            if isActivated {
                usdtEstimate = try await tronUsdtApi.estimateTransferFees(
                    wallet: sourceWallet,
                    address: sourceAddress,
                    method: method
                )
            } else {
                usdtEstimate = try await tronUsdtApi.estimateInactiveAccountTransferFees(
                    address: sourceAddress,
                    method: method
                )
            }
        }

        var nativeEstimate: TronTransferFeeEstimate?
        if hasTRXBalance {
            nativeEstimate = try await tronUsdtApi.estimateNativeTransferFees(
                wallet: sourceWallet,
                from: sourceAddress,
                to: destinationAddress,
                amountSun: max(balance.trxAmount, 1),
                // The USDT leg goes out first and drains whichever pool paid for it, so the sweep
                // reserves against what it leaves behind instead of the account's original allowance.
                bandwidthAllowance: usdtEstimate?.remainingBandwidth
            )
        }

        let feeEstimate = usdtEstimate ?? nativeEstimate
        guard let feeEstimate else {
            return nil
        }

        let usdtRequiredTRXSun = usdtEstimate?.requiredTRXSun ?? 0
        let nativeRequiredTRXSun = nativeEstimate?.selfPaidTRXSun ?? 0
        let requiredTRXSun = usdtEstimate?.requiredTRXSun ?? nativeRequiredTRXSun

        let feeResolver = TronUSDTFeeOptionsResolver(configuration: configuration)
        let resolved = feeResolver.resolve(
            estimate: feeEstimate,
            wallet: sourceWallet,
            preferredExtraType: nil
        )
        let availableFeeMethods = WalletMigrationTronFeeOptionsResolver.resolve(
            availableTypes: resolved.availableTypes,
            requiredBatteryCharges: feeEstimate.requiredBatteryCharges,
            requiredTRXSun: requiredTRXSun,
            isAccountActivated: isActivated
        )

        let result = WalletMigrationTronPrepareResult(
            sourceAddress: sourceAddress.base58,
            destinationAddress: destinationAddress.base58,
            usdtAmount: hasUSDT ? balance.amount : 0,
            requiredTRXSun: requiredTRXSun,
            availableTRXSun: availableTRXSun,
            usdtRequiredTRXSun: usdtRequiredTRXSun,
            nativeRequiredTRXSun: nativeRequiredTRXSun,
            energy: usdtEstimate?.energy ?? 0,
            bandwidth: usdtEstimate?.bandwidth ?? feeEstimate.bandwidth,
            trxEnergy: nativeEstimate?.energy ?? 0,
            trxBandwidth: nativeEstimate?.bandwidth ?? 0,
            destinationRequiresActivation: nativeEstimate?.requiresSelfPaidTRX ?? false,
            availableFeeMethods: availableFeeMethods
        )

        guard result.hasAssets else {
            return nil
        }

        return result
    }

    func getMigrationWallets(
        wallets: [Wallet],
        currency: Currency
    ) async throws -> [WalletMigrationWalletValue] {
        guard let network = wallets.first?.network else {
            return []
        }

        let accountIds = try wallets.map { try $0.tonMigrationAccountId() }
        let response = try await apiProvider.api(network).getMigrationWallets(
            accountIds: accountIds,
            currency: currency
        )
        try Task.checkCancellation()

        let tronBalances = await loadTronBalances(for: wallets)
        try Task.checkCancellation()

        let rates = await loadRates(
            currency: currency,
            includingTron: tronBalances.values.contains { $0.amount > 0 || $0.trxAmount > 0 }
        )
        try Task.checkCancellation()

        return try makeValues(
            wallets: wallets,
            response: response,
            tronBalances: tronBalances,
            rates: rates,
            currency: currency
        )
    }

    private func makeValues(
        wallets: [Wallet],
        response: MigrationWallets,
        tronBalances: [String: TronBalance],
        rates: MigrationRates,
        currency: Currency
    ) throws -> [WalletMigrationWalletValue] {
        try wallets.map { wallet in
            let account = try wallet.tonMigrationAccountId()
            let apiValue = response.wallets.first { matches(account: $0.account, wallet: wallet) }
            let tron = tronBalances[wallet.id]
            let usdtAmount = tron?.amount ?? 0
            let trxAmount = tron?.trxAmount ?? 0

            return WalletMigrationWalletValue(
                account: apiValue?.account ?? account,
                balance: apiValue?.balance ?? 0,
                jettonsCount: apiValue?.jettons.count ?? 0,
                nftCount: apiValue?.nftCount ?? 0,
                usdtAmount: usdtAmount,
                trxAmount: trxAmount,
                fiatBalance: fiatBalance(
                    tonBalance: apiValue?.balance ?? 0,
                    jettons: apiValue?.jettons ?? [],
                    usdtAmount: usdtAmount,
                    trxAmount: trxAmount,
                    currency: currency,
                    rates: rates
                )
            )
        }
    }

    private func cachedRates(currency: Currency) -> MigrationRates {
        let cached = tonRatesStore.getState()
        return MigrationRates(
            ton: cached.tonRates.first { $0.currency == currency },
            usdt: cached.usdtRates.first { $0.currency == currency },
            trx: nil
        )
    }

    private func loadRates(currency: Currency, includingTron: Bool) async -> MigrationRates {
        let cached = cachedRates(currency: currency)

        guard cached.ton == nil || includingTron else {
            return cached
        }

        do {
            let loaded = try await ratesService.loadRates(
                jettons: includingTron ? [TRX.symbol] : [],
                currencies: [currency]
            )
            return MigrationRates(
                ton: loaded.ton.first { $0.currency == currency } ?? cached.ton,
                usdt: loaded.usdt.first { $0.currency == currency } ?? cached.usdt,
                trx: loaded.jettonRates
                    .first { $0.key.caseInsensitiveCompare(TRX.symbol) == .orderedSame }?
                    .value
                    .first { $0.currency == currency }
            )
        } catch {
            return cached
        }
    }

    private func fiatBalance(
        tonBalance: Int64,
        jettons: [TonAPI.JettonBalance],
        usdtAmount: BigUInt,
        trxAmount: BigUInt,
        currency: Currency,
        rates: MigrationRates
    ) -> Decimal {
        let converter = RateConverter()
        var total = Decimal.zero

        if tonBalance > 0, let tonRate = rates.ton {
            total += converter.convertToDecimal(
                amount: BigUInt(tonBalance),
                amountFractionLength: TonInfo.fractionDigits,
                rate: tonRate
            )
        }

        for jetton in jettons {
            guard let price = jetton.price?.prices?[currency.code],
                  let quantity = BigUInt(jetton.balance),
                  quantity > 0
            else {
                continue
            }
            total += converter.convertToDecimal(
                amount: quantity,
                amountFractionLength: jetton.jetton.decimals,
                rate: Rates.Rate(currency: currency, rate: Decimal(price), diff24h: nil)
            )
        }

        if usdtAmount > 0, let usdtRate = rates.usdt {
            total += converter.convertToDecimal(
                amount: usdtAmount,
                amountFractionLength: USDT.fractionDigits,
                rate: usdtRate
            )
        }

        if trxAmount > 0, let trxRate = rates.trx {
            total += converter.convertToDecimal(
                amount: trxAmount,
                amountFractionLength: TRX.fractionDigits,
                rate: trxRate
            )
        }

        return total
    }

    private func loadTronBalances(for wallets: [Wallet]) async -> [String: TronBalance] {
        let addressByWalletId = wallets.reduce(into: [String: TronSwift.Address]()) { result, wallet in
            guard wallet.tron != nil,
                  let address = try? wallet.tronMigrationAddress()
            else {
                return
            }
            result[wallet.id] = address
        }
        return await WalletMigrationTronBalanceLoading.load(
            addressByWalletId: addressByWalletId,
            batchLoad: { [tronBalanceService, tronBalanceCache] addresses in
                var balances = [String: TronBalance]()
                var missing = [TronSwift.Address]()
                for address in addresses {
                    if let cached = await tronBalanceCache.freshBalance(for: address.base58) {
                        balances[address.base58] = cached
                    } else {
                        missing.append(address)
                    }
                }
                guard !missing.isEmpty else {
                    return balances
                }
                let loaded = try await tronBalanceService.loadAccountBalancesBatch(addresses: missing)
                for (address, balance) in loaded {
                    await tronBalanceCache.store(balance, for: address)
                    balances[address] = balance
                }
                return balances
            },
            fallbackBalance: { [tronBalanceCache] address in
                await tronBalanceCache.lastKnownBalance(for: address.base58)
            },
            loadBalance: { [tronBalanceService, tronBalanceCache] address in
                let key = address.base58
                if let cached = await tronBalanceCache.freshBalance(for: key) {
                    return cached
                }
                let balance = try await tronBalanceService.loadAccountBalances(address: address)
                await tronBalanceCache.store(balance, for: key)
                return balance
            }
        )
    }

    private func matches(account: String, wallet: Wallet) -> Bool {
        guard let walletAddress = try? wallet.tonMigrationAccountId(),
              let lhs = try? TonSwift.Address.parse(walletAddress),
              let rhs = try? TonSwift.Address.parse(account)
        else {
            return false
        }
        return lhs == rhs
    }
}

enum WalletMigrationTronBalanceLoading {
    static func load(
        addressByWalletId: [String: TronSwift.Address],
        batchLoad: (@Sendable ([TronSwift.Address]) async throws -> [String: TronBalance])? = nil,
        fallbackBalance: (@Sendable (TronSwift.Address) async -> TronBalance?)? = nil,
        loadBalance: @escaping @Sendable (TronSwift.Address) async throws -> TronBalance
    ) async -> [String: TronBalance] {
        guard !Task.isCancelled else { return [:] }

        let uniqueAddresses = Dictionary(
            addressByWalletId.values.map { ($0.base58, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var balancesByAddress = [String: TronBalance]()
        if let batchLoad {
            do {
                balancesByAddress = try await batchLoad(Array(uniqueAddresses.values))
            } catch {
                guard !Task.isCancelled else { return [:] }
                Log.migration.w("tron balances batch failed, falling back per-address", error: error)
            }
        }

        guard !Task.isCancelled else { return [:] }
        let missingAddresses = uniqueAddresses.filter { balancesByAddress[$0.key] == nil }
        if !missingAddresses.isEmpty {
            let loaded = await loadIndividually(
                addresses: missingAddresses,
                loadBalance: loadBalance,
                fallbackBalance: fallbackBalance
            )
            balancesByAddress.merge(loaded) { _, new in new }
        }

        return addressByWalletId.reduce(into: [String: TronBalance]()) { result, item in
            guard let balance = balancesByAddress[item.value.base58] else { return }
            result[item.key] = balance
        }
    }

    private static func loadIndividually(
        addresses: [String: TronSwift.Address],
        loadBalance: @escaping @Sendable (TronSwift.Address) async throws -> TronBalance,
        fallbackBalance: (@Sendable (TronSwift.Address) async -> TronBalance?)?
    ) async -> [String: TronBalance] {
        await withTaskGroup(of: (String, TronBalance)?.self) { group in
            for (addressKey, address) in addresses {
                group.addTask {
                    guard !Task.isCancelled else { return nil }
                    do {
                        let balance = try await loadBalance(address)
                        guard !Task.isCancelled else { return nil }
                        return (addressKey, balance)
                    } catch {
                        guard !Task.isCancelled else { return nil }
                        if let fallback = await fallbackBalance?(address) {
                            Log.migration.w("tron balance refresh failed, using stale cache", error: error, extraInfo: [
                                "address": addressKey,
                            ])
                            return (addressKey, fallback)
                        }
                        Log.migration.w("tron balance failed", error: error, extraInfo: [
                            "address": addressKey,
                        ])
                        return nil
                    }
                }
            }

            var result = [String: TronBalance]()
            for await item in group {
                guard let item else { continue }
                result[item.0] = item.1
            }
            return result
        }
    }
}

actor TronMigrationBalanceCache {
    private struct Entry {
        let balance: TronBalance
        let storedAt: DispatchTime
    }

    private let ttlNanoseconds: UInt64
    private var entries = [String: Entry]()

    init(ttl: TimeInterval) {
        ttlNanoseconds = UInt64(max(0, ttl) * 1_000_000_000)
    }

    func freshBalance(for address: String) -> TronBalance? {
        guard let entry = entries[address],
              DispatchTime.now().uptimeNanoseconds - entry.storedAt.uptimeNanoseconds < ttlNanoseconds
        else {
            return nil
        }
        return entry.balance
    }

    func lastKnownBalance(for address: String) -> TronBalance? {
        entries[address]?.balance
    }

    func store(_ balance: TronBalance, for address: String) {
        entries[address] = Entry(balance: balance, storedAt: .now())
    }
}
