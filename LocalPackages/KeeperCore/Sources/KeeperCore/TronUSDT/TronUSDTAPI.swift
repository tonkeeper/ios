import BigInt
import Foundation
import TKLogging
import TronSwift
import TronSwiftAPI

public struct TronUSDTAPI {
    private let tronApi: TronApi
    private let batteryAPI: BatteryAPI
    private let batteryService: BatteryService
    private let chainParametersRepository: TronChainParametersRepository

    init(
        tronApi: TronApi,
        batteryAPI: BatteryAPI,
        batteryService: BatteryService,
        chainParametersRepository: TronChainParametersRepository
    ) {
        self.tronApi = tronApi
        self.batteryAPI = batteryAPI
        self.batteryService = batteryService
        self.chainParametersRepository = chainParametersRepository
    }

    public func loadAllTronEvents(
        wallet: Wallet,
        events: [TronTransaction],
        address: Address,
        limit: Int,
        startTimestamp: Int64?,
        finishTimestamp: Int64?
    ) async throws -> [TronTransaction] {
        let batteryEvents = try await loadBatteryTronEvents(
            wallet: wallet,
            events: [],
            address: address,
            limit: limit,
            startTimestamp: startTimestamp,
            finishTimestamp: finishTimestamp
        )

        let events = try await loadTronEvents(
            events: [],
            address: address,
            limit: limit,
            startTimestamp: startTimestamp.map { $0 * 1000 },
            finishTimestamp: finishTimestamp.map { $0 * 1000 }
        )

        return Self.mergeDeduplicatingByTxID(batteryEvents, events)
    }

    static func mergeDeduplicatingByTxID(
        _ lhs: [TronTransaction],
        _ rhs: [TronTransaction]
    ) -> [TronTransaction] {
        var seenTxIDs = Set<String>()
        let merged = (lhs + rhs).filter { seenTxIDs.insert($0.txID).inserted }
        return merged.sorted { $0.timestamp > $1.timestamp }
    }

    public func loadBatteryTronEvents(
        wallet: Wallet,
        events: [TronTransaction],
        address: Address,
        limit: Int,
        startTimestamp: Int64?,
        finishTimestamp: Int64?
    ) async throws -> [TronTransaction] {
        let batteryResponse = try await batteryService.loadTronTransactions(
            wallet: wallet,
            limit: limit,
            maxTimestamp: startTimestamp
        )

        guard let oldestTimestamp = batteryResponse.map(\.timestamp).min() else { return events }
        guard let finishTimestamp else { return batteryResponse }

        guard let nextMaxTimestamp = Self.nextBatteryHistoryPageMaxTimestamp(
            pageCount: batteryResponse.count,
            limit: limit,
            oldestTimestamp: oldestTimestamp,
            finishTimestamp: finishTimestamp
        ) else {
            return events + batteryResponse.filter { $0.timestamp >= finishTimestamp }
        }

        return try await loadBatteryTronEvents(
            wallet: wallet,
            events: events + batteryResponse,
            address: address,
            limit: limit,
            startTimestamp: nextMaxTimestamp,
            finishTimestamp: finishTimestamp
        )
    }

    /// `maxTimestamp` is an inclusive upper bound, so the next page has to start strictly below the
    /// oldest event already collected — asking from the boundary itself returns the same page again.
    /// A page shorter than `limit` is the end of the history and must not be paged past.
    static func nextBatteryHistoryPageMaxTimestamp(
        pageCount: Int,
        limit: Int,
        oldestTimestamp: Int64,
        finishTimestamp: Int64
    ) -> Int64? {
        guard oldestTimestamp > finishTimestamp, pageCount >= limit else { return nil }
        return oldestTimestamp - 1
    }

    static func nextTronHistoryFingerprint(
        pageCount: Int,
        limit: Int,
        fingerprint: String?
    ) -> String? {
        guard pageCount >= limit else {
            return nil
        }
        return fingerprint
    }

    /// TRX transfers are a sliver of a USDT-heavy account's feed and keyless TronGrid allows under
    /// one request a second, so a page is the largest TronGrid serves.
    static let accountTransactionsPageSize = 200

    public func loadTRXTransfers(
        address: Address,
        limit: Int,
        startTimestamp: Int64?
    ) async throws -> [TronTransaction] {
        var transfers = [TronTransaction]()
        var fingerprint: String?
        while transfers.count < limit {
            let page = try await tronApi.getTronAccountTransactions(
                address: address,
                limit: Self.accountTransactionsPageSize,
                maxTimestamp: startTimestamp.map { $0 * 1000 },
                fingerprint: fingerprint
            )
            transfers += page.data.compactMap(TronTransaction.init(accountTransaction:))
            guard let nextFingerprint = Self.nextTronHistoryFingerprint(
                pageCount: page.data.count,
                limit: Self.accountTransactionsPageSize,
                fingerprint: page.fingerprint
            ), nextFingerprint != fingerprint else {
                break
            }
            fingerprint = nextFingerprint
        }
        return transfers
    }

    public func estimateTransferFees(
        wallet: Wallet,
        address: Address,
        method: ContractMethod
    ) async throws -> TronTransferFeeEstimate {
        do {
            let (energy, bandwidth) = try await tronApi.estimateUSDTResources(
                owner: address,
                method: method
            )
            return try await makeTransferFeeEstimate(
                wallet: wallet,
                address: address,
                energy: energy,
                bandwidth: bandwidth
            )
        } catch {
            Log.tron.w("Estimate TRC20 fees failed", extraInfo: [
                "wallet": address.base58.pretty.masked,
                "error": "\(error)",
            ])
            throw error
        }
    }

    public func estimateInactiveAccountTransferFees(
        address: Address,
        method: ContractMethod
    ) async throws -> TronTransferFeeEstimate {
        do {
            let (energy, bandwidth) = try await tronApi.estimateUSDTResources(
                owner: address,
                method: method
            )
            let (marginEnergy, marginBandwidth) = applySafetyMargin(
                energy: energy,
                bandwidth: bandwidth,
                percent: 3
            )
            let requiredTRXAmountSun = try await estimateTRXBurnAmountSun(
                energy: marginEnergy,
                bandwidth: marginBandwidth
            )
            return TronTransferFeeEstimate(
                energy: marginEnergy,
                bandwidth: marginBandwidth,
                requiredBatteryCharges: 0,
                requiredTRXSun: requiredTRXAmountSun,
                requiredTONAmountNano: nil,
                tonFeeAddress: nil
            )
        } catch {
            Log.tron.w("Estimate inactive TRC20 fees failed", extraInfo: [
                "wallet": address.base58.pretty.masked,
                "error": "\(error)",
            ])
            throw error
        }
    }

    public func estimateNativeTransferFees(
        wallet: Wallet,
        from address: Address,
        to destination: Address,
        amountSun: BigUInt,
        bandwidthAllowance: TronBandwidthAllowance? = nil
    ) async throws -> TronTransferFeeEstimate {
        let destinationRequiresActivation = try await !isAccountActivated(address: destination)
        // The activation burn replaces the per-byte charge, so the exact size is not needed there.
        let bandwidth = if destinationRequiresActivation {
            TronApi.defaultNativeTransferBandwidth
        } else {
            TronApi.nativeTransferBandwidth(amountSun: amountSun)
        }

        return try await makeTransferFeeEstimate(
            wallet: wallet,
            address: address,
            energy: 0,
            bandwidth: bandwidth,
            destinationRequiresActivation: destinationRequiresActivation,
            bandwidthAllowance: bandwidthAllowance
        )
    }

    public func loadTrxBalanceSun(address: Address) async throws -> BigUInt {
        try await tronApi.tronBalances(owner: address).trxAmount
    }

    public func getNativeTransferTransaction(
        from address: Address,
        to destination: Address,
        amountSun: BigUInt
    ) async throws -> Transaction {
        try await tronApi.createNativeTransfer(
            owner: address,
            to: destination,
            amountSun: amountSun
        )
    }

    private func makeTransferFeeEstimate(
        wallet: Wallet,
        address: Address,
        energy: Int,
        bandwidth: Int,
        destinationRequiresActivation: Bool = false,
        bandwidthAllowance: TronBandwidthAllowance? = nil
    ) async throws -> TronTransferFeeEstimate {
        let (marginEnergy, marginBandwidth) = try await applySafetyMargin(
            energy: energy,
            bandwidth: bandwidth
        )
        let allowance: TronBandwidthAllowance
        if let bandwidthAllowance {
            allowance = bandwidthAllowance
        } else {
            let accountBandwidth = try await tronApi.getAccountBandwidth(owner: address)
            allowance = TronBandwidthAllowance(
                staked: accountBandwidth.staked,
                free: accountBandwidth.free
            )
        }
        let charge = Self.chargeBandwidth(
            transactionBandwidth: bandwidth,
            burnBandwidth: marginBandwidth,
            allowance: allowance
        )
        let effectiveBandwidth = destinationRequiresActivation ? 0 : charge.burnedBandwidth
        let requiredTRXAmountSun = try await estimateTRXBurnAmountSun(
            energy: marginEnergy,
            bandwidth: effectiveBandwidth
        )
        // Creating the account replaces this transfer's own per-byte charge, so it is weighed against
        // the staked pool as the earlier legs left it, not against what `charge` would have drained.
        let destinationActivationSun = try await destinationActivationFeeSun(
            requiresActivation: destinationRequiresActivation,
            stakedBandwidth: allowance.staked,
            transferBandwidth: bandwidth
        )
        // Quote Battery with the transfer's own resources. Burned leftover after the
        // free/staked pools is only for the self-paid TRX amount — using it here
        // sends energy=0&bandwidth=0, which the battery API rejects.
        let batteryResources = Self.batterySponsoredResources(
            marginEnergy: marginEnergy,
            marginBandwidth: marginBandwidth,
            destinationRequiresActivation: destinationRequiresActivation
        )
        var requiredBatteryCharges = 0
        var requiredTONAmountNano: BigUInt?
        var tonFeeAddress: String?
        if let batteryResources {
            do {
                let estimate = try await batteryService.estimateTronTransaction(
                    wallet: wallet,
                    tronAddress: address.base58,
                    energy: batteryResources.energy,
                    bandwidth: batteryResources.bandwidth
                )
                let tonInstantFeeAsset = estimate.instant_fee.accepted_assets
                    .first {
                        $0._type == .ton
                    }
                requiredTONAmountNano = tonInstantFeeAsset.flatMap {
                    BigUInt($0.amount_nano)
                }
                tonFeeAddress = requiredTONAmountNano == nil ? nil : estimate.instant_fee.fee_address
                requiredBatteryCharges = estimate.total_charges
            } catch {
                if (error as? BatteryAPI.ApiError)?.isCancellation == true || error.isCancelledError {
                    throw CancellationError()
                }
                Log.tron.w("Battery TRC20 estimate failed; using local TRX estimate", extraInfo: [
                    "wallet": address.base58.pretty.masked,
                    "error": "\(error)",
                ])
            }
        }

        return TronTransferFeeEstimate(
            energy: batteryResources?.energy ?? marginEnergy,
            bandwidth: batteryResources?.bandwidth ?? 0,
            remainingBandwidth: charge.remaining,
            requiredBatteryCharges: requiredBatteryCharges,
            requiredTRXSun: requiredTRXAmountSun,
            destinationActivationSun: destinationActivationSun,
            requiredTONAmountNano: requiredTONAmountNano,
            tonFeeAddress: tonFeeAddress
        )
    }

    /// Resources the battery relay should quote and later sponsor. Activation replaces the
    /// per-byte bandwidth charge with a protocol burn that cannot be sponsored, so that
    /// bandwidth is left out. A `(0, 0)` pair must not be sent: the battery API rejects it.
    static func batterySponsoredResources(
        marginEnergy: Int,
        marginBandwidth: Int,
        destinationRequiresActivation: Bool
    ) -> (energy: Int, bandwidth: Int)? {
        let energy = max(marginEnergy, 0)
        let bandwidth = destinationRequiresActivation ? 0 : max(marginBandwidth, 0)
        guard energy > 0 || bandwidth > 0 else {
            return nil
        }
        return (energy, bandwidth)
    }

    private func estimateTRXBurnAmountSun(energy: Int, bandwidth: Int) async throws -> BigUInt {
        let fees = try await chainFees()
        return BigUInt(energy) * fees.energySun + BigUInt(bandwidth) * fees.bandwidthSun
    }

    /// A transfer that has to create the destination account burns `getCreateNewAccountFeeInSystemContract`
    /// from the sender, and pays the account-creation bandwidth either with staked bandwidth or, failing
    /// that, with a `getCreateAccountFee` burn — the ordinary per-byte charge is skipped either way.
    /// Neither burn can be sponsored, so both have to stay out of a full-balance sweep.
    private func destinationActivationFeeSun(
        requiresActivation: Bool,
        stakedBandwidth: Int,
        transferBandwidth: Int
    ) async throws -> BigUInt {
        guard requiresActivation else { return 0 }
        let fees = try await chainFees()
        return Self.activationFeeSun(
            createNewAccountSun: fees.createNewAccountSun,
            createAccountSun: fees.createAccountSun,
            stakedBandwidth: stakedBandwidth,
            transferBandwidth: transferBandwidth,
            createNewAccountBandwidthRate: fees.createNewAccountBandwidthRate
        )
    }

    struct BandwidthCharge: Equatable {
        let burnedBandwidth: Int
        let remaining: TronBandwidthAllowance
    }

    /// `BandwidthProcessor` offers the whole transaction to the staked pool, then to the free pool,
    /// and only burns TRX when neither covers it on its own — the pools are never summed, and a burn
    /// leaves both of them untouched for the next transfer.
    static func chargeBandwidth(
        transactionBandwidth: Int,
        burnBandwidth: Int,
        allowance: TronBandwidthAllowance
    ) -> BandwidthCharge {
        let transactionCost = max(transactionBandwidth, 0)
        if allowance.staked >= transactionCost {
            return BandwidthCharge(
                burnedBandwidth: 0,
                remaining: TronBandwidthAllowance(
                    staked: allowance.staked - transactionCost,
                    free: allowance.free
                )
            )
        }
        if allowance.free >= transactionCost {
            return BandwidthCharge(
                burnedBandwidth: 0,
                remaining: TronBandwidthAllowance(
                    staked: allowance.staked,
                    free: allowance.free - transactionCost
                )
            )
        }
        return BandwidthCharge(
            burnedBandwidth: max(burnBandwidth, transactionCost),
            remaining: allowance
        )
    }

    /// `transferBandwidth` is the raw transaction size: the node weighs it against
    /// `getCreateNewAccountBandwidthRate`, without the local safety margin.
    static func activationFeeSun(
        createNewAccountSun: BigUInt,
        createAccountSun: BigUInt,
        stakedBandwidth: Int,
        transferBandwidth: Int,
        createNewAccountBandwidthRate: BigUInt
    ) -> BigUInt {
        // Free bandwidth does not cover account creation, only staked bandwidth does.
        let bandwidthCost = BigUInt(max(transferBandwidth, 0)) * createNewAccountBandwidthRate
        let coveredByBandwidth = BigUInt(max(stakedBandwidth, 0)) >= bandwidthCost
        return createNewAccountSun + (coveredByBandwidth ? 0 : createAccountSun)
    }

    private func chainFees() async throws -> (
        energySun: BigUInt,
        bandwidthSun: BigUInt,
        createAccountSun: BigUInt,
        createNewAccountSun: BigUInt,
        createNewAccountBandwidthRate: BigUInt
    ) {
        let fees: TronChainFees
        if let cached = await chainParametersRepository.chainFees() {
            fees = cached
        } else {
            let loaded = try await tronApi.getChainFees()
            fees = TronChainFees(
                energySun: loaded.energySun,
                bandwidthSun: loaded.bandwidthSun,
                createAccountSun: loaded.createAccountSun,
                createNewAccountSun: loaded.createNewAccountSun,
                createNewAccountBandwidthRate: loaded.createNewAccountBandwidthRate
            )
            await chainParametersRepository.setChainFees(fees)
        }

        func sun(_ value: Int64, _ name: String) -> BigUInt {
            if value < 0 {
                Log.tron.w("negative \(name): \(value)")
            }
            return BigUInt(UInt64(max(value, 0)))
        }

        return (
            energySun: sun(fees.energySun, "energySun"),
            bandwidthSun: sun(fees.bandwidthSun, "bandwidthSun"),
            createAccountSun: sun(fees.createAccountSun, "createAccountSun"),
            createNewAccountSun: sun(fees.createNewAccountSun, "createNewAccountSun"),
            createNewAccountBandwidthRate: sun(
                fees.createNewAccountBandwidthRate,
                "createNewAccountBandwidthRate"
            )
        )
    }

    public func loadTronEvents(
        events: [TronTransaction],
        address: Address,
        limit: Int,
        startTimestamp: Int64?,
        finishTimestamp: Int64?
    ) async throws -> [TronTransaction] {
        try await loadTronEvents(
            events: events,
            address: address,
            limit: limit,
            startTimestamp: startTimestamp,
            finishTimestamp: finishTimestamp,
            fingerprint: nil
        )
    }

    private func loadTronEvents(
        events: [TronTransaction],
        address: Address,
        limit: Int,
        startTimestamp: Int64?,
        finishTimestamp: Int64?,
        fingerprint: String?
    ) async throws -> [TronTransaction] {
        let tronResponse = try await tronApi.getTronHistory(
            address: address,
            limit: limit,
            minTimestamp: finishTimestamp,
            maxTimestamp: startTimestamp,
            fingerprint: fingerprint
        )
        let transactions = tronResponse.data.map { TronTransaction(tronTransaction: $0) }
        guard finishTimestamp != nil else { return transactions }

        guard let nextFingerprint = Self.nextTronHistoryFingerprint(
            pageCount: transactions.count,
            limit: limit,
            fingerprint: tronResponse.fingerprint
        ), nextFingerprint != fingerprint else {
            return events + transactions
        }

        return try await loadTronEvents(
            events: events + transactions,
            address: address,
            limit: limit,
            startTimestamp: startTimestamp,
            finishTimestamp: finishTimestamp,
            fingerprint: nextFingerprint
        )
    }

    public func sendTransaction(
        wallet: Wallet,
        address: Address,
        signedTransaction: Transaction,
        energy: Int,
        bandwidth: Int,
        instantFeeTx: String? = nil,
        userPublicKey: String? = nil
    ) async throws -> String {
        let transactionData = try JSONSerialization.data(withJSONObject: signedTransaction.toJson())
        let tx = transactionData.base64EncodedString()
        return try await batteryService.sendTronTransaction(
            wallet: wallet,
            tronAddress: address.base58,
            transaction: tx,
            energy: energy,
            bandwidth: bandwidth,
            instantFeeTransaction: instantFeeTx,
            userPublicKey: userPublicKey
        )
    }

    public func broadcastSignedTransaction(transaction: Transaction) async throws {
        try await tronApi.broadcastSignedTransaction(transaction: transaction)
    }

    public func getTransactionInfo(txId: String) async throws -> TronTransactionInfoResponse? {
        try await tronApi.getTransactionInfo(txId: txId)
    }

    public func getSendTransaction(address: Address, method: ContractMethod) async throws -> Transaction {
        try await tronApi.getTransferTransaction(owner: address, method: method)
    }

    public func isAccountActivated(address: Address) async throws -> Bool {
        try await tronApi.tronAccountExists(owner: address)
    }

    private func applySafetyMargin(energy: Int, bandwidth: Int) async throws -> (energy: Int, bandwidth: Int) {
        let percent: Int
        do {
            let batteryConfig = try await batteryAPI.getTronConfig()
            percent = Int(batteryConfig.safety_margin_percent) ?? 3
        } catch {
            if error.isCancellation {
                throw CancellationError()
            }
            Log.tron.w("Battery TRC20 config failed; using default safety margin", extraInfo: [
                "error": "\(error)",
            ])
            percent = 3
        }
        return applySafetyMargin(
            energy: energy,
            bandwidth: bandwidth,
            percent: percent
        )
    }

    private func applySafetyMargin(
        energy: Int,
        bandwidth: Int,
        percent: Int
    ) -> (energy: Int, bandwidth: Int) {
        let safetyMargin = Double(max(percent, 0)) / 100

        let marginEnergy = Int(ceil(Double(energy) * (1 + safetyMargin)))
        let marginBandwidth = Int(ceil(Double(bandwidth) * (1 + safetyMargin)))

        return (marginEnergy, marginBandwidth)
    }
}
