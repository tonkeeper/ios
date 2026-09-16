import BigInt
import Foundation
import TKBatteryAPI
import TKLogging
import TonSwift
import TronSwift

public final class MultichainTransactionConfirmationController: TransactionConfirmationController {
    public var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)? {
        didSet {
            feeEngine?.signHandler = signHandler
        }
    }

    public var tronSignHandler: ((TronSwift.TxID, Wallet) async throws(TronTransferSignError) -> TronSwift.SignedTxID)? {
        didSet {
            (feeEngine as? TronUSDTTransactionConfirmationController)?.tronSignHandler = tronSignHandler
        }
    }

    @Atomic private var extraState: TransactionConfirmationModel.ExtraState = .loading
    @Atomic private var totalFee: BigInt = 0
    @Atomic private var feeEngine: TransactionConfirmationController?
    @Atomic private var engineExtraOptions: [TransactionConfirmationModel.ExtraOption]?
    @Atomic private var chainKitEmulation: MultichainTransactionEmulationResult?
    @Atomic private var isChainKitFallback = false
    @Atomic private var hasUserSelectedFeeMethod = false
    @Atomic private var cachedJettonTransferCost: BigUInt?
    @Atomic private var cachedFeeBalances: MultichainFeeBalances?

    private let wallet: Wallet
    private let recipient: MultichainRecipient
    private let asset: MultichainAsset
    private let amount: BigUInt
    private let comment: String?
    private let isMaxAmount: Bool
    private let chainKitService: ChainKitService
    private let passcodeProvider: () async -> String?
    private let engine: MultichainFeeEngineResolver.Engine
    private let tonJettonEngineFactory: MultichainTonJettonEngineFactory
    private let tronUsdtApi: TronUSDTAPI
    private let sendService: SendService
    private let balanceService: BalanceService
    private let configuration: Configuration
    private let batteryService: BatteryService
    private let batteryChargesReader: BatteryChargesReader
    private let multichainAssetBalanceProvider: MultichainAssetBalanceProvider

    init(
        wallet: Wallet,
        recipient: MultichainRecipient,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        isMaxAmount: Bool,
        chainKitService: ChainKitService,
        passcodeProvider: @escaping () async -> String?,
        engineResolver: MultichainFeeEngineResolver,
        tonJettonEngineFactory: MultichainTonJettonEngineFactory,
        tronUsdtApi: TronUSDTAPI,
        sendService: SendService,
        balanceService: BalanceService,
        configuration: Configuration,
        batteryService: BatteryService,
        batteryCalculation: BatteryCalculation,
        multichainAssetBalanceProvider: MultichainAssetBalanceProvider
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.asset = asset
        self.amount = amount
        self.comment = comment
        self.isMaxAmount = isMaxAmount
        self.chainKitService = chainKitService
        self.passcodeProvider = passcodeProvider
        engine = engineResolver.resolve(asset: asset, wallet: wallet)
        self.tonJettonEngineFactory = tonJettonEngineFactory
        self.tronUsdtApi = tronUsdtApi
        self.sendService = sendService
        self.balanceService = balanceService
        self.configuration = configuration
        self.batteryService = batteryService
        batteryChargesReader = BatteryChargesReader(
            batteryService: batteryService,
            batteryCalculation: batteryCalculation
        )
        self.multichainAssetBalanceProvider = multichainAssetBalanceProvider
    }

    private var feeSelection: MultichainFeeSelection {
        MultichainFeeSelection(engine: engine, transferAmount: amount)
    }

    public func getModel() -> TransactionConfirmationModel {
        let engineModel = isChainKitFallback ? nil : feeEngine?.getModel()
        let extraState = engineModel?.extraState ?? self.extraState
        let extraOptions = engineExtraOptions ?? engineModel?.extraOptions ?? []
        let availableExtraTypes = engineModel?.availableExtraTypes ?? []

        return TransactionConfirmationModel(
            wallet: wallet,
            recipient: recipient.domain,
            recipientAddress: recipient.address,
            transaction: .transfer(.multichain(asset)),
            amount: .init(
                token: .multichain(asset),
                value: engineModel?.amount?.value ?? Self.chainKitAmount(
                    requestedAmount: amount,
                    emulation: chainKitEmulation
                )
            ),
            extraState: extraState,
            extraOptions: extraOptions,
            comment: comment,
            availableExtraTypes: availableExtraTypes,
            isMax: engineModel?.isMax ?? Self.chainKitIsMax(
                requestedIsMax: isMaxAmount,
                emulation: chainKitEmulation
            ),
            totalFee: engineModel?.totalFee ?? totalFee
        )
    }

    public func setLoading() {
        extraState = .loading
        engineExtraOptions = nil
        chainKitEmulation = nil
        isChainKitFallback = false
        cachedFeeBalances = nil
        feeEngine?.setLoading()
    }

    public func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType) {
        hasUserSelectedFeeMethod = true
        feeEngine?.setPrefferedExtraType(extraType: extraType)
    }

    public func emulate() async -> Result<Void, TransactionConfirmationError> {
        guard !isChainKitFallback, engine != .chainKit else {
            return await emulateWithChainKit()
        }

        guard let feeEngine = await resolveFeeEngine() else {
            isChainKitFallback = true
            return await emulateWithChainKit()
        }

        let result = await feeEngine.emulate()
        switch result {
        case .success:
            var extraOptions = await resolvedExtraOptions(for: feeEngine)

            let trxFeeType = feeSelection.trxTypeToPreselect(
                in: extraOptions,
                hasUserSelectedFeeMethod: hasUserSelectedFeeMethod
            )
            if let trxFeeType, let switched = await switchFeeMethod(feeEngine, to: trxFeeType) {
                extraOptions = switched
            }

            engineExtraOptions = extraOptions

            if isSelectedOptionInsufficient(in: extraOptions, feeEngine: feeEngine) {
                await feeEngine.prepareFeeOptions()
                extraOptions = await resolvedExtraOptions(for: feeEngine)
                engineExtraOptions = extraOptions

                if !hasUserSelectedFeeMethod,
                   isSelectedOptionInsufficient(in: extraOptions, feeEngine: feeEngine),
                   let sufficientType = firstSufficientExtraType(in: extraOptions, feeEngine: feeEngine),
                   let switched = await switchFeeMethod(feeEngine, to: sufficientType)
                {
                    engineExtraOptions = switched
                }
            }
        case .failure:
            engineExtraOptions = nil
            isChainKitFallback = true
            return await emulateWithChainKit()
        }
        return result
    }

    public func prepareFeeOptions() async {
        guard !isChainKitFallback, engine != .chainKit,
              let feeEngine = await resolveFeeEngine()
        else {
            return
        }
        cachedFeeBalances = nil
        await feeEngine.prepareFeeOptions()
        engineExtraOptions = await resolvedExtraOptions(for: feeEngine)
    }

    public func sendTransaction() async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        let feeEngine = !isChainKitFallback && engine != .chainKit
            ? await resolveFeeEngine()
            : nil

        if let feeEngine {
            await repriceTRXFeeIfNeeded(feeEngine)
        }

        guard !getModel().isSelectedFeeInsufficient else {
            return .failure(
                .multichainTransactionFailure(.insufficientSelectedFee)
            )
        }

        guard let feeEngine else {
            return await sendWithChainKit()
        }
        return await feeEngine.sendTransaction()
    }

    /// A TRX-paid transfer burns whatever the chain charges at broadcast time, so the quote can be
    /// stale by the time it is confirmed. Re-price it keeping the chosen method — switching silently
    /// would send a transaction the user did not approve — and let the guard above stop a send the
    /// balance no longer covers. A failed re-price keeps the previous quote.
    private func repriceTRXFeeIfNeeded(_ feeEngine: TransactionConfirmationController) async {
        guard case .tronUSDT = engine,
              selectedExtraType(of: feeEngine)?.isTRXGasless == true,
              case .success = await feeEngine.emulate()
        else {
            return
        }
        cachedFeeBalances = nil
        engineExtraOptions = await resolvedExtraOptions(for: feeEngine)
    }

    private func resolveFeeEngine() async -> TransactionConfirmationController? {
        if let feeEngine {
            return feeEngine
        }

        let feeEngine: TransactionConfirmationController?
        switch engine {
        case let .tronUSDT(tronAddress):
            guard let senderAddress = try? TronSwift.Address(address: tronAddress),
                  let tronRecipient = try? TronRecipient(address: recipient.address)
            else {
                return nil
            }
            feeEngine = TronUSDTTransactionConfirmationController(
                wallet: wallet,
                token: .usdt,
                recipient: tronRecipient,
                amount: amount,
                balance: asset.balance,
                senderAddress: senderAddress,
                recipientDisplayAddress: recipient.address,
                tronUsdtApi: tronUsdtApi,
                sendService: sendService,
                balanceService: balanceService,
                configuration: configuration
            )

        case let .tonJetton(master):
            feeEngine = await tonJettonEngineFactory.makeController(
                wallet: wallet,
                recipient: recipient.address,
                master: master,
                amount: amount,
                comment: comment
            )

        case .chainKit:
            feeEngine = nil
        }

        guard let feeEngine else {
            return nil
        }
        feeEngine.signHandler = signHandler
        if let tronFeeEngine = feeEngine as? TronUSDTTransactionConfirmationController {
            tronFeeEngine.tronSignHandler = tronSignHandler
        }
        self.feeEngine = feeEngine
        return feeEngine
    }

    private func emulateWithChainKit() async -> Result<Void, TransactionConfirmationError> {
        do {
            let result = try await chainKitService.emulateTransaction(
                wallet: wallet,
                recipient: recipient.address,
                asset: asset,
                amount: amount,
                comment: comment,
                isMaxAmount: isMaxAmount
            )
            chainKitEmulation = result
            engineExtraOptions = Self.chainKitExtraOptions(emulation: result)
            await updateFee(emulationResult: result)
            return .success(())
        } catch {
            Log.e(
                "🪵 Multichain: chainKit fee emulation failed",
                error: error,
                extraInfo: [
                    "assetId": asset.asset.assetId,
                    "isMax": "\(isMaxAmount)",
                ]
            )
            chainKitEmulation = nil
            await updateFee(emulationResult: nil)
            return .failure(.multichainTransactionFailure(.emulationFailure(error)))
        }
    }

    private func sendWithChainKit() async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        guard case .Regular = wallet.identity.kind else {
            let error = MultichainTransactionFailure.internal(
                reason: "wallet type is not supported for multichain transfers"
            )
            Log.e(
                "🪵 Multichain: chainKit transfer rejected",
                error: error,
                extraInfo: [
                    "assetId": asset.asset.assetId,
                    "isMax": "\(isMaxAmount)",
                ]
            )
            return .failure(
                .multichainTransactionFailure(error)
            )
        }

        do {
            let txHashes = try await chainKitService.sendMultichainTransfer(
                passcodeProvider: passcodeProvider,
                wallet: wallet,
                recipient: recipient.address,
                asset: asset,
                amount: amount,
                comment: comment,
                isMaxAmount: isMaxAmount
            )
            return .success(chainKitSendResult(txHashes: txHashes))
        } catch {
            if case .canceled = error {
                Log.i(
                    "🪵 Multichain: chainKit transfer cancelled",
                    error: error,
                    extraInfo: [
                        "assetId": asset.asset.assetId,
                        "isMax": "\(isMaxAmount)",
                    ]
                )
                return .failure(.cancelledByUser)
            }
            Log.e(
                "🪵 Multichain: chainKit transfer failed",
                error: error,
                extraInfo: [
                    "assetId": asset.asset.assetId,
                    "isMax": "\(isMaxAmount)",
                ]
            )
            return .failure(
                .multichainTransactionFailure(error)
            )
        }
    }

    private func chainKitSendResult(txHashes: [String]) -> TransactionConfirmationSendResult {
        guard let chain = asset.asset.chain else {
            Log.w(
                "🪵 Multichain: broadcast not recorded, unresolved chain",
                extraInfo: ["assetId": asset.asset.assetId]
            )
            return .nothingToRecord
        }
        return .chain(chain, wallet: wallet, txHashes: txHashes, activityType: .send)
    }

    private func extraOptionsWithInsufficiency(
        _ extraOptions: [TransactionConfirmationModel.ExtraOption]
    ) async -> [TransactionConfirmationModel.ExtraOption] {
        feeSelection.annotatingInsufficiency(extraOptions, balances: await feeBalances())
    }

    /// One snapshot per emulation: the options a single decision is made from must be annotated
    /// against balances read at the same moment, and an asset the wallet does not hold leaves
    /// nothing in the provider's cache to read back.
    private func feeBalances() async -> MultichainFeeBalances {
        if let cachedFeeBalances {
            return cachedFeeBalances
        }
        async let batteryCharges = availableBatteryCharges()
        async let tonBalance = nativeBalance(for: .ton)
        async let trxBalance = nativeBalance(for: .tron)
        async let jettonForwardCost = jettonTransferCost()

        let balances = MultichainFeeBalances(
            batteryCharges: await batteryCharges,
            ton: await tonBalance,
            trx: await trxBalance,
            jettonForwardAmount: await jettonForwardCost
        )
        cachedFeeBalances = balances
        return balances
    }

    private func jettonTransferCost() async -> BigUInt {
        guard case let .tonJetton(master) = engine else {
            return 0
        }
        if let cachedJettonTransferCost {
            return cachedJettonTransferCost
        }
        let config = try? await batteryService.loadBatteryConfig(wallet: wallet)
        let masterAddress = try? TonSwift.Address.parse(master)
        let cost = config?.transferCost(jettonMasterAddress: masterAddress)
            ?? Components.Schemas.Config.fallbackTransferCost
        cachedJettonTransferCost = cost
        return cost
    }

    private func availableBatteryCharges() async -> BatteryChargesAvailability {
        await batteryChargesReader.availableCharges(wallet: wallet)
    }

    /// Switches the fee engine to `type` and re-emulates. If that emulation fails — which for some
    /// engines clears the current fee state — restores the previously selected type and re-emulates
    /// so a valid fee stays available. Returns the resolved options for the resulting state, or nil
    /// if no valid state could be produced (leaving the caller's current options untouched).
    private func switchFeeMethod(
        _ feeEngine: TransactionConfirmationController,
        to type: TransactionConfirmationModel.ExtraType
    ) async -> [TransactionConfirmationModel.ExtraOption]? {
        let previousExtraType = selectedExtraType(of: feeEngine)
        setFeeMethod(feeEngine, to: type)
        if case .success = await feeEngine.emulate() {
            return await resolvedExtraOptions(for: feeEngine)
        }
        guard let previousExtraType else {
            return nil
        }
        setFeeMethod(feeEngine, to: previousExtraType)
        if case .success = await feeEngine.emulate() {
            return await resolvedExtraOptions(for: feeEngine)
        }
        return nil
    }

    private func setFeeMethod(
        _ feeEngine: TransactionConfirmationController,
        to type: TransactionConfirmationModel.ExtraType
    ) {
        if let jettonFeeEngine = feeEngine as? JettonTransferTransactionConfirmationController {
            jettonFeeEngine.setExtraTypeForCurrentTransaction(extraType: type)
        } else {
            feeEngine.setPrefferedExtraType(extraType: type)
        }
    }

    private func resolvedExtraOptions(
        for feeEngine: TransactionConfirmationController
    ) async -> [TransactionConfirmationModel.ExtraOption] {
        let extraOptions = feeEngine.getModel().extraOptions
        switch engine {
        case .tronUSDT, .tonJetton:
            return await extraOptionsWithInsufficiency(extraOptions)
        case .chainKit:
            return extraOptions
        }
    }

    private func selectedExtraType(
        of feeEngine: TransactionConfirmationController
    ) -> TransactionConfirmationModel.ExtraType? {
        guard case let .extra(extra) = feeEngine.getModel().extraState else {
            return nil
        }
        return extra.value.extraType
    }

    private func isSelectedOptionInsufficient(
        in options: [TransactionConfirmationModel.ExtraOption],
        feeEngine: TransactionConfirmationController
    ) -> Bool {
        guard let selectedType = selectedExtraType(of: feeEngine) else {
            return false
        }
        return options.first { $0.type == selectedType }?.isInsufficient ?? false
    }

    private func firstSufficientExtraType(
        in options: [TransactionConfirmationModel.ExtraOption],
        feeEngine: TransactionConfirmationController
    ) -> TransactionConfirmationModel.ExtraType? {
        let selectedType = selectedExtraType(of: feeEngine)
        return feeEngine.getModel().availableExtraTypes.first { type in
            guard type != selectedType,
                  let option = options.first(where: { $0.type == type })
            else {
                return false
            }
            return !option.isInsufficient
        }
    }

    private func nativeBalance(for chain: MultichainChain) async -> BigUInt? {
        await multichainAssetBalanceProvider.loadBalance(
            for: "\(chain.rawValue)/mainnet/coin",
            wallet: wallet
        )
    }

    private func updateFee(emulationResult: MultichainTransactionEmulationResult?) async {
        guard let emulationResult else {
            totalFee = 0
            extraState = .none
            return
        }

        totalFee = BigInt(emulationResult.fee)
        extraState = .extra(
            TransactionConfirmationModel.Extra(
                value: .multichain(
                    token: emulationResult.asset,
                    amount: emulationResult.fee
                ),
                kind: .fee
            )
        )
    }
}

extension MultichainTransactionConfirmationController {
    static func chainKitAmount(
        requestedAmount: BigUInt,
        emulation: MultichainTransactionEmulationResult?
    ) -> BigUInt {
        emulation?.adjustedAmount ?? requestedAmount
    }

    static func chainKitIsMax(
        requestedIsMax: Bool,
        emulation: MultichainTransactionEmulationResult?
    ) -> Bool {
        emulation?.isMaxAmount ?? requestedIsMax
    }

    static func chainKitExtraOptions(
        emulation: MultichainTransactionEmulationResult
    ) -> [TransactionConfirmationModel.ExtraOption]? {
        guard emulation.isInsufficientBalance else {
            return nil
        }
        return [
            TransactionConfirmationModel.ExtraOption(
                type: .multichain(token: emulation.asset),
                value: .multichain(token: emulation.asset, amount: emulation.fee),
                isInsufficient: true
            ),
        ]
    }
}
