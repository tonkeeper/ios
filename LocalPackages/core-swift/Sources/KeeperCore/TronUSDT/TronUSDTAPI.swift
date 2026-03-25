import BigInt
import Foundation
import TKLogging
import TronSwift
import TronSwiftAPI

public struct TronUSDTAPI {
    private let tronApi: TronApi
    private let batteryAPI: BatteryAPI
    private let chainParametersRepository: TronChainParametersRepository

    init(
        tronApi: TronApi,
        batteryAPI: BatteryAPI,
        chainParametersRepository: TronChainParametersRepository
    ) {
        self.tronApi = tronApi
        self.batteryAPI = batteryAPI
        self.chainParametersRepository = chainParametersRepository
    }

    public func loadAllTronEvents(
        events: [TronTransaction],
        address: Address,
        limit: Int,
        tonProofToken: String,
        startTimestamp: Int64?,
        finishTimestamp: Int64?
    ) async throws -> [TronTransaction] {
        let batteryEvents = try await loadBatteryTronEvents(
            events: [],
            address: address,
            limit: limit,
            tonProofToken: tonProofToken,
            startTimestamp: startTimestamp,
            finishTimestamp: finishTimestamp
        )

        let events = try await loadTronEvents(
            events: [],
            address: address,
            limit: limit,
            tonProofToken: tonProofToken,
            startTimestamp: startTimestamp.map { $0 * 1000 },
            finishTimestamp: finishTimestamp.map { $0 * 1000 }
        )

        return Array(Set(batteryEvents).union(Set(events)))
    }

    public func loadBatteryTronEvents(
        events: [TronTransaction],
        address: Address,
        limit: Int,
        tonProofToken: String,
        startTimestamp: Int64?,
        finishTimestamp: Int64?
    ) async throws -> [TronTransaction] {
        let batteryResponse = try await batteryAPI.getTronTransactions(
            tonProofToken: tonProofToken,
            limit: limit,
            maxTimestamp: startTimestamp
        )

        guard let lastEvent = batteryResponse.last else { return [] }

        if let finishTimestamp {
            if lastEvent.timestamp < finishTimestamp || batteryResponse.count < limit {
                let filtered = batteryResponse.filter { $0.timestamp >= finishTimestamp }
                return events + filtered
            } else {
                return try await loadBatteryTronEvents(
                    events: events + batteryResponse,
                    address: address,
                    limit: limit,
                    tonProofToken: tonProofToken,
                    startTimestamp: lastEvent.timestamp + 1,
                    finishTimestamp: finishTimestamp
                )
            }
        } else {
            return batteryResponse
        }
    }

    public func estimateTransferFees(
        address: Address,
        method: ContractMethod
    ) async throws -> TronTransferFeeEstimate {
        do {
            let (energy, bandwidth) = try await tronApi.estimateUSDTResources(
                owner: address,
                method: method
            )
            let (marginEnergy, marginBandwidth) = try await applySafetyMargin(
                energy: energy,
                bandwidth: bandwidth
            )
            let freeBandwidth = try await tronApi.getAccountBandwidth(owner: address)
            let effectiveBandwidth = freeBandwidth >= marginBandwidth ? 0 : marginBandwidth
            let requiredTRXAmountSun = try await estimateTRXBurnAmountSun(
                energy: marginEnergy,
                bandwidth: effectiveBandwidth
            )
            let estimate = try await batteryAPI.getTronEstimate(
                address: address.base58,
                energy: marginEnergy,
                bandwidth: marginBandwidth
            )

            let tonInstantFeeAsset = estimate.instant_fee.accepted_assets
                .first {
                    $0._type == .ton
                }
            let requiredTONAmountNano = tonInstantFeeAsset.flatMap {
                BigUInt($0.amount_nano)
            }
            let tonFeeAddress = requiredTONAmountNano == nil ? nil : estimate.instant_fee.fee_address

            return TronTransferFeeEstimate(
                energy: marginEnergy,
                bandwidth: marginBandwidth,
                requiredBatteryCharges: estimate.total_charges,
                requiredTRXSun: requiredTRXAmountSun,
                requiredTONAmountNano: requiredTONAmountNano,
                tonFeeAddress: tonFeeAddress
            )
        } catch {
            Log.tron.w("Estimate TRC20 fees failed", extraInfo: [
                "wallet": address.base58.pretty.masked,
                "error": "\(error)",
            ])
            throw error
        }
    }

    private func estimateTRXBurnAmountSun(energy: Int, bandwidth: Int) async throws -> BigUInt {
        let prices = try await trxResourcePrices()
        return BigUInt(energy) * prices.energySun + BigUInt(bandwidth) * prices.bandwidthSun
    }

    private func trxResourcePrices() async throws -> (energySun: BigUInt, bandwidthSun: BigUInt) {
        let cached = await chainParametersRepository.trxResourcePrices()
        if let cached {
            do {
                return try makeTRXResourcePrices(
                    energySun: cached.energySun,
                    bandwidthSun: cached.bandwidthSun
                )
            } catch {
                Log.tron.w("failed to read cached resource prices due to error: \(error.localizedDescription)")
                Log.tron.i("fetching resource prices...")
            }
        }
        let (energySun, bandwidthSun) = try await tronApi.getResourcePrices()
        let prices = try makeTRXResourcePrices(
            energySun: energySun,
            bandwidthSun: bandwidthSun
        )
        await chainParametersRepository.setTrxResourcePrices(
            TronTRXResourcePrices(
                energySun: energySun,
                bandwidthSun: bandwidthSun
            )
        )
        return prices
    }

    func makeTRXResourcePrices(
        energySun: Int64,
        bandwidthSun: Int64
    ) throws -> (energySun: BigUInt, bandwidthSun: BigUInt) {
        if energySun < 0 {
            Log.tron.w("negative energySun: \(energySun)")
        }
        if bandwidthSun < 0 {
            Log.tron.w("negative bandwidthSun: \(bandwidthSun)")
        }
        return (
            energySun: BigUInt(UInt64(max(energySun, 0))),
            bandwidthSun: BigUInt(UInt64(max(bandwidthSun, 0)))
        )
    }

    public func loadTronEvents(
        events: [TronTransaction],
        address: Address,
        limit: Int,
        tonProofToken: String,
        startTimestamp: Int64?,
        finishTimestamp: Int64?
    ) async throws -> [TronTransaction] {
        let tronResponse = try await tronApi.getTronHistory(
            address: address,
            limit: limit,
            minTimestamp: nil,
            maxTimestamp: startTimestamp,
            fingerprint: nil
        )
        let transactions = tronResponse.data.map { TronTransaction(tronTransaction: $0) }
        guard let lastEvent = tronResponse.data.last else { return [] }

        if let finishTimestamp {
            if lastEvent.timestamp >= finishTimestamp {
                return try await loadBatteryTronEvents(
                    events: events + transactions,
                    address: address,
                    limit: limit,
                    tonProofToken: tonProofToken,
                    startTimestamp: lastEvent.timestamp + 1,
                    finishTimestamp: finishTimestamp
                )
            } else {
                let filtered = transactions.filter { $0.timestamp >= finishTimestamp }
                return events + filtered
            }
        } else {
            return transactions
        }
    }

    public func sendTransaction(
        tonProofToken: String,
        address: Address,
        signedTransaction: Transaction,
        energy: Int,
        bandwidth: Int,
        instantFeeTx: String? = nil,
        userPublicKey: String? = nil
    ) async throws -> String {
        let transactionData = try JSONSerialization.data(withJSONObject: signedTransaction.toJson())
        let tx = transactionData.base64EncodedString()
        return try await batteryAPI.tronSend(
            tonProofToken: tonProofToken,
            wallet: address.base58,
            tx: tx,
            energy: energy,
            bandwidth: bandwidth,
            instantFeeTx: instantFeeTx,
            userPublicKey: userPublicKey
        )
    }

    public func broadcastSignedTransaction(transaction: Transaction) async throws {
        try await tronApi.broadcastSignedTransaction(transaction: transaction)
    }

    public func getSendTransaction(address: Address, method: ContractMethod) async throws -> Transaction {
        try await tronApi.getTransferTransaction(owner: address, method: method, feeLimit: 150_000_000)
    }

    public func extendTransactionExpiration(
        transaction: Transaction,
        expirationExtension: Int64
    ) async throws -> Transaction {
        var transaction = transaction
        transaction.rawData.expiration += expirationExtension
        return try await tronApi.getSignWeightTransaction(transaction: transaction)
    }

    public func estimateBatteryCharges(address: Address, method: ContractMethod) async throws -> (energy: Int, bandwidth: Int, estimateCharges: Int) {
        let (energy, bandwidth) = try await tronApi.estimateUSDTResources(owner: address, method: method)
        let (marginEnergy, marginBandwidth) = try await applySafetyMargin(energy: energy, bandwidth: bandwidth)
        let estimate = try await batteryAPI.getTronEstimate(address: address.base58, energy: marginEnergy, bandwidth: marginBandwidth)
        return (marginEnergy, marginBandwidth, estimate.total_charges)
    }

    private func applySafetyMargin(energy: Int, bandwidth: Int) async throws -> (energy: Int, bandwidth: Int) {
        let batteryConfig = try await batteryAPI.getTronConfig()
        let safetyMargin = Double(Int(batteryConfig.safety_margin_percent) ?? 3) / 100

        let marginEnergy = Int(ceil(Double(energy) * (1 + safetyMargin)))
        let marginBandwidth = Int(ceil(Double(bandwidth) * (1 + safetyMargin)))

        return (marginEnergy, marginBandwidth)
    }
}
