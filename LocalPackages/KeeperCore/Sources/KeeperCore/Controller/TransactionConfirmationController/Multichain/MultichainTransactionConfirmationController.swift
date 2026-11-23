import BigInt
import Foundation
import OperationReviewModels
import TKBatteryAPI
import TKLogging
import TonSwift
import TronSwift

public final class MultichainTransactionConfirmationController: TransactionConfirmationController {
    public var batteryPasscodeHandoff: (@MainActor (String?) -> Void)?
    public var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)? {
        didSet {
            if let feeEngine {
                feeEngine.signHandler = gatedSignHandler(for: feeEngine)
            }
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
    @Atomic private var evmQuote: EVMGaslessFeeEngine.Quote?
    @Atomic private var evmPickedType: TransactionConfirmationModel.ExtraType?

    private let wallet: Wallet
    private let recipient: MultichainRecipient
    private let asset: MultichainAsset
    private let amount: BigUInt
    private let comment: String?
    /// The recipient's TON public key, hex, when the comment goes encrypted to it.
    private let commentEncryptionKey: String?
    /// Whether chain-kit sends the comment encrypted to `commentEncryptionKey`: a blank comment or an empty
    /// key goes as it is.
    private let encryptsComment: Bool
    private let isMaxAmount: Bool
    private let chainKitService: ChainKitService
    private let signer: MultichainTransferSigner
    private let engineResolver: MultichainFeeEngineResolver
    @Atomic private var resolvedEngine: MultichainFeeEngineResolver.Resolution?
    private let tonJettonEngineFactory: MultichainTonJettonEngineFactory
    private let tronUsdtApi: TronUSDTAPI
    private let sendService: SendService
    private let balanceService: BalanceService
    private let configuration: Configuration
    private let isGenericPayloadEnabled: Bool
    private let batteryService: BatteryService
    private let batteryChargesReader: BatteryChargesReader
    private let multichainAssetBalanceProvider: MultichainAssetBalanceProvider
    private let evmGaslessFeeEngine: EVMGaslessFeeEngine
    private let gate: OperationGate
    private let batteryPaymentPreparation: BatteryPaymentPreparation
    private let feeCalculationGate: MultichainFeeCalculationGate

    init(
        wallet: Wallet,
        recipient: MultichainRecipient,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        commentEncryptionKey: String? = nil,
        isMaxAmount: Bool,
        chainKitService: ChainKitService,
        signer: MultichainTransferSigner,
        engineResolver: MultichainFeeEngineResolver,
        tonJettonEngineFactory: MultichainTonJettonEngineFactory,
        tronUsdtApi: TronUSDTAPI,
        sendService: SendService,
        balanceService: BalanceService,
        configuration: Configuration,
        batteryService: BatteryService,
        batteryCalculation: BatteryCalculation,
        multichainAssetBalanceProvider: MultichainAssetBalanceProvider,
        evmGaslessFeeEngine: EVMGaslessFeeEngine,
        gate: OperationGate,
        offersBatteryMigration: @escaping (Wallet) async -> Bool = { _ in false },
        batteryPaymentPreparation: BatteryPaymentPreparation = BatteryPaymentPreparation(),
        feeCalculationGate: MultichainFeeCalculationGate = MultichainFeeCalculationGate()
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.asset = asset
        self.amount = amount
        self.comment = comment
        self.commentEncryptionKey = commentEncryptionKey
        encryptsComment = MultichainEncryptedComment(text: comment, key: commentEncryptionKey) != nil
        self.isMaxAmount = isMaxAmount
        self.chainKitService = chainKitService
        self.signer = signer
        self.engineResolver = engineResolver
        self.tonJettonEngineFactory = tonJettonEngineFactory
        self.tronUsdtApi = tronUsdtApi
        self.sendService = sendService
        self.balanceService = balanceService
        self.configuration = configuration
        isGenericPayloadEnabled = configuration.featureEnabled(.genericPayloadEnabled)
        self.batteryService = batteryService
        batteryChargesReader = BatteryChargesReader(
            batteryService: batteryService,
            batteryCalculation: batteryCalculation,
            offersMigration: offersBatteryMigration
        )
        self.multichainAssetBalanceProvider = multichainAssetBalanceProvider
        self.evmGaslessFeeEngine = evmGaslessFeeEngine
        self.gate = gate
        self.batteryPaymentPreparation = batteryPaymentPreparation
        self.feeCalculationGate = feeCalculationGate
    }

    /// ChainKit cannot sign TON for a Ledger, so a failed TON engine is the answer rather than a cue to try it.
    private func canFallBackToChainKit(from engine: MultichainFeeEngineResolver.Engine) -> Bool {
        guard wallet.kind == .ledger else {
            return true
        }
        if case .tronUSDT = engine {
            return true
        }
        return false
    }

    private var deviceSigner: DeviceTransferSigner? {
        guard case let .device(device) = signer else {
            return nil
        }
        return device
    }

    /// A settled engine is kept for the controller's life, a provisional one only until the next load.
    private func engine() async -> MultichainFeeEngineResolver.Engine {
        if let resolvedEngine {
            return resolvedEngine.engine
        }
        let resolution = await engineResolver.resolve(asset: asset, wallet: wallet)
        resolvedEngine = resolution
        return resolution.engine
    }

    private func feeSelection(engine: MultichainFeeEngineResolver.Engine) -> MultichainFeeSelection {
        MultichainFeeSelection(engine: engine, transferAmount: amount)
    }

    /// The transfer as the relayer is asked to carry it.
    private func evmTransfer(engine: MultichainFeeEngineResolver.Engine) -> EVMGaslessFeeEngine.Transfer? {
        guard case let .evm(chain) = engine else {
            return nil
        }
        return EVMGaslessFeeEngine.Transfer(
            wallet: wallet,
            chain: chain,
            asset: asset,
            amount: amount,
            recipient: recipient.address,
            comment: comment
        )
    }

    public func getModel() -> TransactionConfirmationModel {
        let engineModel = isChainKitFallback ? nil : feeEngine?.getModel()
        let operationPaid = engineModel.flatMap(operationPaidSelection)
        let extraState = keepsUnavailableBatterySelection
            ? self.extraState
            : operationPaid.map { $0.method.extraState(fee: $0.emulation.fee) } ?? engineModel?.extraState ?? self.extraState
        let extraOptions = engineExtraOptions ?? engineModel?.extraOptions ?? []
        let chainKitEmulation = self.chainKitEmulation
        let listedTypes = engineModel?.availableExtraTypes ?? engineExtraOptions?.map(\.type) ?? []
        // Once the options are priced, the coin's method that chain-kit priced no operation for is not offered.
        let availableExtraTypes = engineExtraOptions == nil
            ? listedTypes
            : resolvedEngine.flatMap { operationPaidMethod($0.engine) }?.available(listedTypes, as: chainKitEmulation) ?? listedTypes
        let evmQuote = self.evmQuote
        let selectedEVMFee = evmQuote?.selected(picked: evmPickedType)

        return TransactionConfirmationModel(
            wallet: wallet,
            recipient: recipient.domain,
            recipientAddress: recipient.address,
            transaction: .transfer(.multichain(asset)),
            amount: .init(
                token: .multichain(asset),
                value: engineModel?.amount?.value ?? Self.sentAmount(
                    requestedAmount: amount,
                    emulation: chainKitEmulation,
                    selectedEVMFee: selectedEVMFee
                )
            ),
            extraState: extraState,
            extraOptions: extraOptions,
            comment: comment,
            isCommentEncrypted: encryptsComment,
            availableExtraTypes: availableExtraTypes,
            isMax: engineModel?.isMax ?? Self.chainKitIsMax(
                requestedIsMax: isMaxAmount,
                emulation: chainKitEmulation
            ),
            totalFee: operationPaid.map { BigInt($0.emulation.fee) } ?? engineModel?.totalFee ?? totalFee,
            review: operationPaid?.emulation.review
                ?? (engineModel == nil ? Self.review(emulation: chainKitEmulation, quote: evmQuote, selectedEVMFee: selectedEVMFee) : nil)
        )
    }

    public func setLoading() {
        extraState = .loading
        engineExtraOptions = nil
        chainKitEmulation = nil
        isChainKitFallback = false
        cachedFeeBalances = nil
        evmQuote = nil
        if resolvedEngine?.isSettled == false {
            resolvedEngine = nil
        }
        feeEngine?.setLoading()
    }

    public func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType) {
        hasUserSelectedFeeMethod = true
        evmQuote?.heldFeeType = nil
        evmPickedType = extraType
        feeEngine?.setPrefferedExtraType(extraType: extraType)
    }

    public func emulate() async -> Result<Void, TransactionConfirmationError> {
        await emulate(preservingBattery: false)
    }

    private func emulate(preservingBattery: Bool) async -> Result<Void, TransactionConfirmationError> {
        guard await feeCalculationGate.acquire() else { return .failure(.cancelledByUser) }
        if !preservingBattery, !Task.isCancelled { setLoading() }
        let result = await emulateSerially(preservingBattery: preservingBattery)
        let outcome: Result<Void, TransactionConfirmationError> = Task.isCancelled ? .failure(.cancelledByUser) : result
        if preservingBattery, case .failure = result {
            showUnavailableBattery(options: getModel().extraOptions)
        }
        await feeCalculationGate.release()
        return outcome
    }

    private func emulateSerially(preservingBattery: Bool) async -> Result<Void, TransactionConfirmationError> {
        guard !Task.isCancelled else { return .failure(.cancelledByUser) }
        let engine = await self.engine()
        // Only chain-kit encrypts a comment: any other engine would send it as it is.
        if encryptsComment, engine != .chainKit {
            return .failure(.multichainTransactionFailure(.internal(reason: "an encrypted comment goes out only through chain-kit")))
        }
        if let evmTransfer = evmTransfer(engine: engine) {
            return await emulateEVM(evmTransfer, preservingBattery: preservingBattery)
        }
        guard !isChainKitFallback, engine != .chainKit else {
            return await emulateWithChainKit()
        }

        guard let feeEngine = await resolveFeeEngine() else {
            guard !Task.isCancelled else { return .failure(.cancelledByUser) }
            guard canFallBackToChainKit(from: engine) else {
                return .failure(.multichainTransactionFailure(.internal(reason: "no TON engine for a Ledger transfer")))
            }
            isChainKitFallback = true
            return await emulateWithChainKit()
        }
        guard !Task.isCancelled else { return .failure(.cancelledByUser) }
        if hasUserSelectedFeeMethod, let evmPickedType {
            setFeeMethod(feeEngine, to: evmPickedType)
        } else {
            (feeEngine as? TronUSDTTransactionConfirmationController)?.resetAutomaticFeePreference()
            (feeEngine as? JettonTransferTransactionConfirmationController)?.resetAutomaticFeePreference()
        }

        let operationPaidMethod = operationPaidMethod(engine)
        let result: Result<Void, TransactionConfirmationError>
        let operationPricingFailure: MultichainTransactionEmulationFailure?
        if operationPaidMethod != nil {
            async let relayed = feeEngine.emulate()
            async let pricing = priceOperationPaidMethod()
            result = await relayed
            operationPricingFailure = await pricing
        } else {
            result = await feeEngine.emulate()
            operationPricingFailure = nil
        }
        guard !Task.isCancelled else { return .failure(.cancelledByUser) }
        switch result {
        case .success:
            var extraOptions = await resolvedExtraOptions(for: feeEngine)
            guard !Task.isCancelled else { return .failure(.cancelledByUser) }
            if let operationPaidMethod, let selected = selectedExtraType(of: feeEngine), operationPaidMethod.pays(with: selected),
               !extraOptions.contains(where: { operationPaidMethod.pays(with: $0.type) })
            {
                // chain-kit priced no operation for the coin to pay: another method the engine offers, or none.
                engineExtraOptions = extraOptions
                guard let switched = await moveFeeMethod(feeEngine, toFirstOf: Self.fallbackFeeMethods(in: extraOptions)) else {
                    return .failure(.multichainTransactionFailure(.emulationFailure(operationPricingFailure ?? .internal(reason: "no method left to pay with"))))
                }
                extraOptions = switched
            }

            let trxFeeType = feeSelection(engine: engine).trxTypeToPreselect(
                in: extraOptions,
                hasUserSelectedFeeMethod: hasUserSelectedFeeMethod
            )
            if let trxFeeType, let switched = await switchFeeMethod(feeEngine, to: trxFeeType) {
                extraOptions = switched
            }

            guard !Task.isCancelled else { return .failure(.cancelledByUser) }
            engineExtraOptions = extraOptions

            if isSelectedOptionInsufficient(in: extraOptions, feeEngine: feeEngine) {
                await feeEngine.prepareFeeOptions()
                extraOptions = await resolvedExtraOptions(for: feeEngine)
                guard !Task.isCancelled else { return .failure(.cancelledByUser) }
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
            guard !preservingBattery else { return result }
            engineExtraOptions = nil
            guard canFallBackToChainKit(from: engine) else {
                return result
            }
            isChainKitFallback = true
            return await emulateWithChainKit()
        }
        return result
    }

    public func prepareFeeOptions() async {
        guard await feeCalculationGate.acquire() else { return }
        if !Task.isCancelled { await prepareFeeOptionsSerially() }
        await feeCalculationGate.release()
    }

    private func prepareFeeOptionsSerially() async {
        let engine = await self.engine()
        if let evmTransfer = evmTransfer(engine: engine), let evmQuote {
            // Keep the quote's chosen method, while the selected row uses the refreshed wallet metadata
            // so its identity still matches the displayed options.
            let options = await evmGaslessFeeEngine.reweighed(evmQuote.options, transfer: evmTransfer)
            guard !Task.isCancelled else { return }
            if let selected = evmQuote.selected(picked: evmPickedType),
               let updated = options.first(where: { $0.relayerAssetId == selected.relayerAssetId })
            {
                extraState = .extra(.init(value: updated.extraValue, kind: .fee))
            }
            engineExtraOptions = options.map(\.extraOption)
            return
        }
        guard !isChainKitFallback, engine != .chainKit,
              let feeEngine = await resolveFeeEngine()
        else {
            return
        }
        let keepsBatteryUnavailable = keepsUnavailableBatterySelection
        cachedFeeBalances = nil
        await feeEngine.prepareFeeOptions()
        let options = await resolvedExtraOptions(for: feeEngine)
        guard !Task.isCancelled else { return }
        if keepsBatteryUnavailable {
            showUnavailableBattery(options: options)
        } else {
            engineExtraOptions = options
        }
    }

    public func sendTransaction() async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        await sendTransaction(consent: .refuse)
    }

    public func sendTransaction(consent: OperationConsent) async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        let confirmed = getModel()
        if case .loading = confirmed.extraState { return .failure(.multichainTransactionFailure(.feeQuoteLoading)) }
        guard case .extra = confirmed.extraState, !confirmed.isSelectedFeeUnavailable else {
            return .failure(.multichainTransactionFailure(.feeMethodUnavailable))
        }
        let prepared: BatteryPaymentPreparation.Prepared?
        do {
            prepared = selectedBattery(confirmed)
                ? try await batteryPaymentPreparation.prepare(wallet: wallet, signer: signer, requiredCharges: batteryFee(confirmed))
                : nil
        } catch is CancellationError {
            return .failure(.cancelledByUser)
        } catch {
            Log.multichain.w("battery migration failed before transfer", error: error)
            return .failure(.multichainTransactionFailure(.batteryMigrationFailed(reason: error.logDescription)))
        }
        if prepared != nil {
            setPrefferedExtraType(extraType: .battery)
            cachedFeeBalances = nil
            if case let .failure(error) = await emulate(preservingBattery: true) { return .failure(error) }
            let updated = getModel()
            guard selectedBattery(updated), !updated.isSelectedFeeInsufficient else {
                return .failure(.multichainTransactionFailure(.insufficientSelectedFee))
            }
            guard let confirmedCharges = batteryFee(confirmed), let charges = batteryFee(updated), charges <= confirmedCharges else {
                return .failure(.multichainTransactionFailure(.relayerQuoteUnavailable(reason: "battery fee needs a fresh confirmation")))
            }
        }
        guard !Task.isCancelled else { return .failure(.cancelledByUser) }
        if let prepared { await batteryPasscodeHandoff?(prepared.passcode) }
        let result = await sendPrepared(signer: prepared?.signer ?? signer, consent: consent)
        if prepared != nil { await batteryPasscodeHandoff?(nil) }
        return result
    }

    private func selectedBattery(_ model: TransactionConfirmationModel) -> Bool {
        guard case let .extra(extra) = model.extraState else { return false }
        return extra.value.extraType.isBattery
    }

    private func batteryFee(_ model: TransactionConfirmationModel) -> Int? {
        guard case let .extra(extra) = model.extraState, case let .battery(charges, _) = extra.value else { return nil }
        return charges
    }

    private func sendPrepared(signer: MultichainTransferSigner, consent: OperationConsent) async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        let engine = await self.engine()
        if evmTransfer(engine: engine) != nil, selectedBattery(getModel()) {
            guard let selected = evmQuote?.selected(picked: evmPickedType), selected.isBattery, selected.isAvailable else {
                return .failure(.multichainTransactionFailure(.feeMethodUnavailable))
            }
            guard !getModel().isSelectedFeeInsufficient else {
                return .failure(.multichainTransactionFailure(.insufficientSelectedFee))
            }
        }
        if let evmTransfer = evmTransfer(engine: engine),
           let quote = evmQuote,
           let selected = quote.selected(picked: evmPickedType),
           selected.isRelayed
        {
            guard selected.isAvailable else {
                return .failure(.multichainTransactionFailure(.feeMethodUnavailable))
            }
            guard !getModel().isSelectedFeeInsufficient else {
                return .failure(.multichainTransactionFailure(.insufficientSelectedFee))
            }
            guard case let .mnemonic(passcodeProvider) = signer else {
                return .failure(.multichainTransactionFailure(.internal(reason: "a hardware wallet cannot sign a relayed transfer")))
            }
            return await evmGaslessFeeEngine.send(
                quote,
                selected: selected,
                transfer: evmTransfer,
                passcodeProvider: passcodeProvider,
                consent: consent
            ).map { txHash in txHash.map { chainKitSendResult(txHashes: [$0]) } ?? .nothingToRecord }
        }

        let feeEngine = !isChainKitFallback && engine != .chainKit
            ? await resolveFeeEngine()
            : nil

        // The coin pays as the operation it was priced as, at that fee: nothing is priced again after the swipe.
        if let feeEngine, let method = operationPaidMethod(engine), let selected = selectedExtraType(of: feeEngine), method.pays(with: selected) {
            guard chainKitEmulation?.operation != nil else {
                return .failure(.multichainTransactionFailure(.internal(reason: "the coin was priced as no operation to sign")))
            }
            guard !getModel().isSelectedFeeInsufficient else {
                return .failure(.multichainTransactionFailure(.insufficientSelectedFee))
            }
            return await sendWithChainKit(signer: signer, consent: consent)
        }

        if let feeEngine {
            await repriceTRXFeeIfNeeded(feeEngine)
        }
        guard !Task.isCancelled else { return .failure(.cancelledByUser) }

        guard !getModel().isSelectedFeeInsufficient else {
            return .failure(
                .multichainTransactionFailure(.insufficientSelectedFee)
            )
        }

        guard let feeEngine else {
            return await sendWithChainKit(signer: signer, consent: consent)
        }
        return await feeEngine.sendTransaction(consent: consent)
    }

    /// A TRX-paid transfer burns whatever the chain charges at broadcast time, so the quote can be
    /// stale by the time it is confirmed. Re-price it keeping the chosen method — switching silently
    /// would send a transaction the user did not approve — and let the guard above stop a send the
    /// balance no longer covers. A failed re-price keeps the previous quote.
    private func repriceTRXFeeIfNeeded(_ feeEngine: TransactionConfirmationController) async {
        guard await feeCalculationGate.acquire() else { return }
        if !Task.isCancelled { await repriceTRXFeeSerially(feeEngine) }
        await feeCalculationGate.release()
    }

    private func repriceTRXFeeSerially(_ feeEngine: TransactionConfirmationController) async {
        guard case .tronUSDT = await engine(),
              selectedExtraType(of: feeEngine)?.isTRXGasless == true,
              case .success = await feeEngine.emulate()
        else {
            return
        }
        guard !Task.isCancelled else { return }
        cachedFeeBalances = nil
        let options = await resolvedExtraOptions(for: feeEngine)
        guard !Task.isCancelled else { return }
        engineExtraOptions = options
    }

    private func resolveFeeEngine() async -> TransactionConfirmationController? {
        if let feeEngine {
            return feeEngine
        }

        let feeEngine: TransactionConfirmationController?
        switch await engine() {
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
                configuration: configuration,
                gate: gate,
                deviceSigner: deviceSigner
            )

        case let .tonJetton(master):
            feeEngine = await tonJettonEngineFactory.makeController(
                wallet: wallet,
                recipient: recipient.address,
                master: master,
                amount: amount,
                comment: comment
            )

        case .tonCoin:
            feeEngine = tonJettonEngineFactory.makeTonController(
                wallet: wallet,
                recipient: recipient.address,
                amount: amount,
                comment: comment,
                isMaxAmount: isMaxAmount
            )

        case .chainKit, .evm:
            feeEngine = nil
        }

        guard let feeEngine else {
            return nil
        }
        feeEngine.signHandler = gatedSignHandler(for: feeEngine)
        if let tronFeeEngine = feeEngine as? TronUSDTTransactionConfirmationController {
            tronFeeEngine.tronSignHandler = tronSignHandler
        }
        self.feeEngine = feeEngine
        return feeEngine
    }

    /// The chain's own fee from ChainKit and the relayer's methods are priced side by side. A
    /// relayer that offers nothing leaves the transfer exactly as it is without one; a ChainKit
    /// emulation that fails only costs the list its coin method while the relayer has others.
    private func emulateEVM(_ transfer: EVMGaslessFeeEngine.Transfer, preservingBattery: Bool) async -> Result<Void, TransactionConfirmationError> {
        let holdsBattery = preservingBattery || (hasUserSelectedFeeMethod && evmPickedType?.isBattery == true)
        async let nativeResult = emulateWithChainKit()
        async let relayedQuote = evmGaslessFeeEngine.estimate(transfer)
        let (native, relayed) = await(nativeResult, relayedQuote)
        guard !Task.isCancelled else { return .failure(.cancelledByUser) }
        guard var quote = relayed else {
            if holdsBattery {
                let options = chainKitEmulation.map { emulation in
                    [EVMGaslessFeeOption(
                        payer: .native(emulation.asset, fee: emulation.fee),
                        relayerAssetId: nil,
                        isInsufficient: emulation.isInsufficientBalance
                    ).extraOption]
                } ?? []
                showUnavailableBattery(options: options)
                return .failure(.multichainTransactionFailure(.feeMethodUnavailable))
            }
            evmQuote = nil
            return native
        }
        if let emulation = chainKitEmulation {
            quote.options.append(
                EVMGaslessFeeOption(
                    payer: .native(emulation.asset, fee: emulation.fee),
                    relayerAssetId: nil,
                    isInsufficient: emulation.isInsufficientBalance
                )
            )
        }
        quote.heldFeeType = holdsBattery ? .battery : nil
        quote = await evmGaslessFeeEngine.quote(quote, picked: evmPickedType, transfer: transfer)
        guard !Task.isCancelled else { return .failure(.cancelledByUser) }
        if holdsBattery, quote.selected(picked: evmPickedType)?.isAvailable != true {
            showUnavailableBattery(options: quote.options.map(\.extraOption))
            return .failure(.multichainTransactionFailure(.feeMethodUnavailable))
        }
        evmQuote = quote
        engineExtraOptions = quote.options.map(\.extraOption)
        if let selected = quote.selected(picked: evmPickedType) {
            extraState = .extra(
                TransactionConfirmationModel.Extra(value: selected.extraValue, kind: .fee)
            )
        }
        return .success(())
    }

    private var keepsUnavailableBatterySelection: Bool {
        guard case let .extra(extra) = extraState, extra.value.extraType.isBattery else { return false }
        return engineExtraOptions?.contains { $0.type.isBattery && !$0.isAvailable } == true
    }

    private func showUnavailableBattery(options: [TransactionConfirmationModel.ExtraOption]) {
        evmQuote = nil
        let value = TransactionConfirmationModel.ExtraValue.battery(charges: nil, excess: nil)
        extraState = .extra(.init(value: value, kind: .fee))
        engineExtraOptions = options.filter { !$0.type.isBattery }
            + [.init(type: .battery, value: value, isAvailable: false)]
    }

    /// While `genericPayloadEnabled` is on, as it was when the controller was built, a
    /// mnemonic's own send on the ChainKit engine is priced as chain-kit's operation for it and that
    /// operation is signed, as are TRON USDT's and a TON jetton's when their chain's coin pays the fee
    /// (`operationPaidMethod`). The SDK keeps a send another engine fell back from, bitcoin, whose memo
    /// chain-kit does not sign, and a whole Base balance: chain-kit's reserve leaves no room for Base's L1
    /// fee, which moves with every L1 block, so a max send signed at the fee priced before the swipe would
    /// be refused once that fee rose.
    private var signsOperation: Bool {
        guard signsOwnOperations else {
            return false
        }
        switch asset.asset.chain {
        case .eth, .arb, .bsc, .polygon, .avax, .robinhood, .tron, .sol:
            return true
        case .base:
            return !(asset.isNative && isMaxAmount)
        case .ton:
            return asset.isNative
        case .btc, nil:
            return false
        }
    }

    /// While `genericPayloadEnabled` is on, a mnemonic's own send, not one an engine fell back
    /// from, may be signed as chain-kit's operation.
    private var signsOwnOperations: Bool {
        guard isGenericPayloadEnabled,
              !isChainKitFallback,
              case .Regular = wallet.identity.kind,
              case .mnemonic = signer
        else {
            return false
        }
        return true
    }

    /// The method the chain's coin pays an engine's send with as chain-kit's operation for it, while
    /// `genericPayloadEnabled` is on: TRX for TRON USDT beside the engine's charges and GRAM, TON
    /// for a TON jetton beside its battery and gasless. A Ledger, and a send the engine fell back from, keep
    /// the engine and the SDK.
    private func operationPaidMethod(_ engine: MultichainFeeEngineResolver.Engine) -> OperationPaidMethod? {
        guard signsOwnOperations else {
            return nil
        }
        return Self.operationPaidMethod(
            for: engine,
            jettonCarriesCustomPayload: (feeEngine as? JettonTransferTransactionConfirmationController)?.carriesCustomPayload
        )
    }

    /// TRX for TRON USDT, TON for a TON jetton the engine knows to carry no payload of its own: chain-kit
    /// attaches none, so a mintless jetton's claim keeps the engine.
    static func operationPaidMethod(
        for engine: MultichainFeeEngineResolver.Engine,
        jettonCarriesCustomPayload: Bool?
    ) -> OperationPaidMethod? {
        switch engine {
        case .tronUSDT:
            .trx
        case .tonJetton:
            jettonCarriesCustomPayload == false ? .ton : nil
        case .tonCoin, .chainKit, .evm:
            nil
        }
    }

    /// Prices the operation the coin pays the engine's send as, carrying the send's comment: that operation
    /// is what the coin's method signs. A failed pricing, returned, only costs the list the coin's option
    /// while the engine offers others.
    private func priceOperationPaidMethod() async -> MultichainTransactionEmulationFailure? {
        do {
            let emulation = try await chainKitService.emulateOperationTransfer(
                wallet: wallet,
                recipient: recipient.address,
                asset: asset,
                amount: amount,
                comment: comment,
                commentEncryptionKey: commentEncryptionKey,
                isMaxAmount: isMaxAmount
            )
            guard !Task.isCancelled else { return .internal(reason: "operation pricing cancelled") }
            chainKitEmulation = emulation
            return nil
        } catch {
            guard !Task.isCancelled else { return .internal(reason: "operation pricing cancelled") }
            Log.e(
                "🪵 Multichain: operation pricing of the coin's method failed",
                error: error,
                extraInfo: ["assetId": asset.asset.assetId]
            )
            chainKitEmulation = nil
            return error
        }
    }

    /// The coin's method and the operation it pays the engine's send as, while that method is on screen.
    private func operationPaidSelection(
        _ engineModel: TransactionConfirmationModel
    ) -> (method: OperationPaidMethod, emulation: MultichainTransactionEmulationResult)? {
        guard let engine = resolvedEngine?.engine,
              let method = operationPaidMethod(engine),
              case let .extra(extra) = engineModel.extraState,
              method.pays(with: extra.value.extraType),
              let emulation = chainKitEmulation,
              emulation.operation != nil
        else {
            return nil
        }
        return (method, emulation)
    }

    private func emulateWithChainKit() async -> Result<Void, TransactionConfirmationError> {
        do {
            let result = if signsOperation {
                try await chainKitService.emulateOperationTransfer(
                    wallet: wallet,
                    recipient: recipient.address,
                    asset: asset,
                    amount: amount,
                    comment: comment,
                    commentEncryptionKey: commentEncryptionKey,
                    isMaxAmount: isMaxAmount
                )
            } else {
                try await chainKitService.emulateTransaction(
                    wallet: wallet,
                    recipient: recipient.address,
                    asset: asset,
                    amount: amount,
                    comment: comment,
                    commentEncryptionKey: commentEncryptionKey,
                    isMaxAmount: isMaxAmount
                )
            }
            guard !Task.isCancelled else { return .failure(.cancelledByUser) }
            chainKitEmulation = result
            engineExtraOptions = Self.chainKitExtraOptions(emulation: result)
            await updateFee(emulationResult: result)
            return .success(())
        } catch {
            guard !Task.isCancelled else { return .failure(.cancelledByUser) }
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

    /// What a fee engine signs TON with: the App's handler, which a TON engine reaches only through the
    /// gate. The TRON engine signs its instant fee through a gate of its own.
    func gatedSignHandler(for feeEngine: TransactionConfirmationController) -> OperationGate.TonSigning? {
        guard let signHandler, !(feeEngine is TronUSDTTransactionConfirmationController) else {
            return signHandler
        }
        return gate.clearing(
            signHandler,
            account: { [asset] wallet in try ChainKitOperationSender.account(wallet: wallet, chain: .ton, holding: asset.asset) },
            intent: .send(amount, of: asset.asset, to: recipient.address)
        )
    }

    private func sendWithChainKit(signer: MultichainTransferSigner, consent: OperationConsent) async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        switch (wallet.identity.kind, signer) {
        case (.Regular, .mnemonic), (.Ledger, .device):
            break
        default:
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
            // The send follows its emulation: what was priced as an operation is what is signed.
            let txHashes = if let emulation = chainKitEmulation, emulation.operation != nil, case let .mnemonic(passcodeProvider) = signer {
                try await chainKitService.sendOperationTransfer(
                    emulation,
                    wallet: wallet,
                    passcodeProvider: passcodeProvider,
                    consent: consent
                )
            } else {
                try await chainKitService.sendMultichainTransfer(
                    signer: signer,
                    wallet: wallet,
                    recipient: recipient.address,
                    asset: asset,
                    amount: amount,
                    comment: comment,
                    commentEncryptionKey: commentEncryptionKey,
                    isMaxAmount: isMaxAmount,
                    consent: consent
                )
            }
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
        await feeSelection(engine: engine()).annotatingInsufficiency(extraOptions, balances: feeBalances())
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
        if !Task.isCancelled { cachedFeeBalances = balances }
        return balances
    }

    private func jettonTransferCost() async -> BigUInt {
        guard case let .tonJetton(master) = await engine() else {
            return 0
        }
        if operationPaidMethod(.tonJetton(master: master)) == .ton, let attached = chainKitEmulation?.operation?.attachedTON {
            return attached
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
        guard !Task.isCancelled else { return nil }
        let previousExtraType = selectedExtraType(of: feeEngine)
        setFeeMethod(feeEngine, to: type)
        if case .success = await feeEngine.emulate() {
            guard !Task.isCancelled else { return nil }
            return await resolvedExtraOptions(for: feeEngine)
        }
        guard !Task.isCancelled else { return nil }
        guard let previousExtraType else {
            return nil
        }
        setFeeMethod(feeEngine, to: previousExtraType)
        if case .success = await feeEngine.emulate() {
            guard !Task.isCancelled else { return nil }
            return await resolvedExtraOptions(for: feeEngine)
        }
        return nil
    }

    /// Moves the send to the first of `types` the engine emulates, never back to the method it leaves; `nil`
    /// when none emulates.
    private func moveFeeMethod(
        _ feeEngine: TransactionConfirmationController,
        toFirstOf types: [TransactionConfirmationModel.ExtraType]
    ) async -> [TransactionConfirmationModel.ExtraOption]? {
        for type in types {
            guard !Task.isCancelled else { return nil }
            setFeeMethod(feeEngine, to: type)
            if case .success = await feeEngine.emulate() {
                guard !Task.isCancelled else { return nil }
                return await resolvedExtraOptions(for: feeEngine)
            }
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
        let engine = await engine()
        let method = operationPaidMethod(engine)
        let emulation = chainKitEmulation
        let extraOptions = method.map { $0.pricing(feeEngine.getModel().extraOptions, as: emulation) }
            ?? feeEngine.getModel().extraOptions
        switch engine {
        case .tronUSDT, .tonJetton:
            let annotated = await extraOptionsWithInsufficiency(extraOptions)
            guard let method, emulation?.isInsufficientBalance == true else {
                return annotated
            }
            // chain-kit's reserve read the coin's balance itself: short there is short on screen.
            return annotated.map { option in
                method.pays(with: option.type)
                    ? TransactionConfirmationModel.ExtraOption(type: option.type, value: option.value, isInsufficient: true)
                    : option
            }
        case .chainKit, .evm, .tonCoin:
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
        guard !Task.isCancelled else { return }
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

    static func sentAmount(
        requestedAmount: BigUInt,
        emulation: MultichainTransactionEmulationResult?,
        selectedEVMFee: EVMGaslessFeeOption?
    ) -> BigUInt {
        guard selectedEVMFee?.isRelayed != true else {
            return requestedAmount
        }
        return chainKitAmount(requestedAmount: requestedAmount, emulation: emulation)
    }

    static func chainKitIsMax(
        requestedIsMax: Bool,
        emulation: MultichainTransactionEmulationResult?
    ) -> Bool {
        emulation?.isMaxAmount ?? requestedIsMax
    }

    /// The methods a send moves to when the coin's is gone, in the order they are tried: the ones the wallet
    /// can pay with, then the others, each as listed.
    static func fallbackFeeMethods(in options: [TransactionConfirmationModel.ExtraOption]) -> [TransactionConfirmationModel.ExtraType] {
        (options.filter { !$0.isInsufficient } + options.filter(\.isInsufficient)).map(\.type)
    }

    /// What the swipe asks about: the relayer's operation while a relayed method holds the selection,
    /// the transfer ChainKit priced otherwise.
    static func review(
        emulation: MultichainTransactionEmulationResult?,
        quote: EVMGaslessFeeEngine.Quote?,
        selectedEVMFee: EVMGaslessFeeOption?
    ) -> OperationReview? {
        selectedEVMFee?.isRelayed == true ? quote?.review : emulation?.review
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

/// The coin's method of an engine's send, priced and signed as chain-kit's operation for it.
enum OperationPaidMethod: Equatable {
    /// TRX for TRON USDT.
    case trx
    /// TON for a TON jetton.
    case ton

    func pays(with type: TransactionConfirmationModel.ExtraType) -> Bool {
        switch self {
        case .trx:
            type.isTRXGasless
        case .ton:
            type == .default
        }
    }

    func value(fee: BigUInt) -> TransactionConfirmationModel.ExtraValue {
        switch self {
        case .trx:
            .gasless(token: TronUSDTFeeOptionsResolver.trxFeeToken, amount: fee)
        case .ton:
            .default(amount: fee)
        }
    }

    func extraState(fee: BigUInt) -> TransactionConfirmationModel.ExtraState {
        .extra(TransactionConfirmationModel.Extra(value: value(fee: fee), kind: .fee))
    }

    /// `types` without the coin's when chain-kit priced no operation for it: the method would have nothing
    /// to sign.
    func available(
        _ types: [TransactionConfirmationModel.ExtraType],
        as emulation: MultichainTransactionEmulationResult?
    ) -> [TransactionConfirmationModel.ExtraType] {
        guard emulation?.operation == nil else {
            return types
        }
        return types.filter { !pays(with: $0) }
    }

    /// `options` with the coin's at what chain-kit's operation costs, or without it when chain-kit priced
    /// no operation for it: that operation is what the coin pays for.
    func pricing(
        _ options: [TransactionConfirmationModel.ExtraOption],
        as emulation: MultichainTransactionEmulationResult?
    ) -> [TransactionConfirmationModel.ExtraOption] {
        options.compactMap { option in
            guard pays(with: option.type) else {
                return option
            }
            guard let emulation, emulation.operation != nil else {
                return nil
            }
            return TransactionConfirmationModel.ExtraOption(type: option.type, value: value(fee: emulation.fee), isInsufficient: option.isInsufficient)
        }
    }
}
