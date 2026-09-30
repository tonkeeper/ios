import BigInt
import Foundation
import KeeperCore
import TKLogging
import TonSwift
import TronSwift

public extension WalletOpen {
    init(wallet: Wallet) {
        let walletMode = WalletMode(wallet: wallet)
        self.init(
            walletMode: walletMode,
            walletSource: WalletSource(wallet: wallet),
            walletInterface: {
                switch walletMode {
                case .multi:
                    nil
                case .single:
                    switch wallet.tonInterface {
                    case .readonly:
                        nil
                    case let .regular(contract):
                        contract.asWalletInterface
                    }
                }
            }()
        )
    }
}

public struct TransactionOrigin {
    public static let user = TransactionOrigin(initiatedBy: .user)

    public let initiatedBy: InitiatedBy
    public let appId: String?
    public let dappUrl: String?
    public let utm: UtmParameters

    public init(
        initiatedBy: InitiatedBy,
        appId: String? = nil,
        dappUrl: String? = nil,
        utm: UtmParameters = .empty
    ) {
        self.initiatedBy = initiatedBy
        self.appId = appId
        self.dappUrl = dappUrl
        self.utm = utm
    }
}

public extension TransactionSent {
    init?(
        wallet: Wallet,
        model: TransactionConfirmationModel,
        origin: TransactionOrigin
    ) {
        let payload = AnalyticsTransactionPayload(model: model, network: wallet.network)

        self.init(
            wallet: wallet,
            category: payload.category,
            categoryDetail: payload.categoryDetail,
            asset: payload.asset,
            amount: payload.amount,
            feeAsset: FeeAsset(extraState: model.extraState, asset: payload.asset),
            origin: origin,
            isMax: payload.isMax,
            toAsset: nil,
            stakingProvider: payload.stakingProvider,
            isLiquid: payload.isLiquid
        )
    }

    init?(
        wallet: Wallet,
        swapFromToken fromToken: KeeperCore.Token,
        toToken: KeeperCore.Token,
        amount: BigUInt,
        feeAsset: FeeAsset,
        origin: TransactionOrigin,
        isMax: Bool?
    ) {
        self.init(
            wallet: wallet,
            swapFromAsset: fromToken.assetId(network: wallet.network),
            fromAssetDecimals: fromToken.fractionDigits,
            toAsset: toToken.assetId(network: wallet.network),
            amount: amount,
            feeAsset: feeAsset,
            origin: origin,
            isMax: isMax
        )
    }

    init?(
        wallet: Wallet,
        swapFromAsset asset: String,
        fromAssetDecimals decimals: Int,
        toAsset: String,
        amount: BigUInt,
        feeAsset: FeeAsset,
        origin: TransactionOrigin,
        isMax: Bool?
    ) {
        self.init(
            wallet: wallet,
            category: .swap,
            categoryDetail: asset.analyticsChain == toAsset.analyticsChain ? .onchain : .crossChain,
            asset: asset,
            amount: Self.normalizedAmount(amount, decimals: decimals),
            feeAsset: feeAsset,
            origin: origin,
            isMax: isMax,
            toAsset: toAsset
        )
    }

    init?(
        wallet: Wallet,
        emulation: SignRawEmulation,
        transferType: TransferType,
        origin: TransactionOrigin
    ) {
        let payload = AnalyticsEmulatedTransactionPayload(emulation: emulation, network: wallet.network)

        self.init(
            wallet: wallet,
            category: payload.category,
            categoryDetail: payload.categoryDetail,
            asset: payload.asset,
            amount: payload.amount,
            feeAsset: FeeAsset(transferType: transferType),
            origin: origin,
            isMax: nil,
            toAsset: payload.toAsset,
            stakingProvider: payload.stakingProvider,
            isLiquid: payload.isLiquid
        )
    }

    init?(
        wallet: Wallet,
        callDetail: CategoryDetail,
        callAmount: Float,
        feeAsset: FeeAsset,
        origin: TransactionOrigin
    ) {
        self.init(
            wallet: wallet,
            category: .call,
            categoryDetail: callDetail,
            asset: KeeperCore.Token.ton(.ton).assetId(network: wallet.network),
            amount: callAmount,
            feeAsset: feeAsset,
            origin: origin,
            isMax: nil
        )
    }

    private init?(
        wallet: Wallet,
        category: Category,
        categoryDetail: CategoryDetail,
        asset: String,
        amount: Float,
        feeAsset: FeeAsset,
        origin: TransactionOrigin,
        isMax: Bool?,
        toAsset: String? = nil,
        stakingProvider: String? = nil,
        isLiquid: Bool? = nil
    ) {
        guard let walletInterface = wallet.transactionInterface(for: asset) else {
            return nil
        }

        self.init(
            category: category,
            categoryDetail: categoryDetail,
            asset: asset,
            amount: amount,
            feeAsset: feeAsset,
            walletInterface: walletInterface,
            walletSource: WalletSource(wallet: wallet),
            walletMode: WalletMode(wallet: wallet),
            initiatedBy: origin.initiatedBy,
            appId: origin.appId,
            dappUrl: origin.dappUrl,
            isMax: isMax,
            toAsset: toAsset,
            stakingProvider: stakingProvider,
            isLiquid: isLiquid
        )
    }

    private static func normalizedAmount(_ amount: BigUInt, decimals: Int) -> Float {
        NSDecimalNumber.fromBigUInt(value: amount, decimals: decimals).floatValue
    }
}

public extension FeeAsset {
    init(extraState: TransactionConfirmationModel.ExtraState, asset: String?) {
        switch extraState {
        case let .extra(extra):
            self.init(extraValue: extra.value, asset: asset)
        case .none, .loading:
            self = .coin
        }
    }

    init(transferType: TransferType) {
        if transferType.isBattery {
            self = .batteryCharges
        } else if transferType.isGasless {
            self = .gasless
        } else {
            self = .coin
        }
    }

    init(multichainSwapFeeMethod method: MultichainSwapFeeMethod) {
        switch method {
        case .native:
            self = .coin
        case .battery:
            self = .batteryCharges
        case .gram:
            self = .batteryTonInstantFee
        }
    }

    init(extraValue: TransactionConfirmationModel.ExtraValue, asset: String?) {
        switch extraValue {
        case .default:
            self = asset.flatMap(MultichainChain.init(assetId:)) == .tron ? .batteryTonInstantFee : .coin
        case .battery:
            self = .batteryCharges
        case let .gasless(token, _):
            self = token.symbol?.uppercased() == TRX.symbol.uppercased() ? .coin : .gasless
        case .multichain:
            self = .coin
        }
    }
}

public extension WalletMode {
    init(wallet: Wallet) {
        self = wallet.isMultichain ? .multi : .single
    }
}

public extension WalletSource {
    init(wallet: Wallet) {
        switch wallet.kind {
        case .regular, .lockup:
            self = .mnemonic
        case .signer:
            self = .signer
        case .ledger:
            self = .ledger
        case .keystone:
            self = .keystone
        case .watchonly:
            self = .watchonly
        }
    }
}

private struct AnalyticsTransactionPayload {
    let category: TransactionSent.Category
    let categoryDetail: TransactionSent.CategoryDetail
    let asset: String
    let amount: Float
    let isMax: Bool?
    let stakingProvider: String?
    let isLiquid: Bool?

    private init(
        category: TransactionSent.Category,
        categoryDetail: TransactionSent.CategoryDetail,
        asset: String,
        amount: Float,
        isMax: Bool?,
        stakingProvider: String?,
        isLiquid: Bool?
    ) {
        self.category = category
        self.categoryDetail = categoryDetail
        self.asset = asset
        self.amount = amount
        self.isMax = isMax
        self.stakingProvider = stakingProvider
        self.isLiquid = isLiquid
    }

    init(model: TransactionConfirmationModel, network: Network) {
        switch model.transaction {
        case let .transfer(transfer):
            self.init(transfer: transfer, model: model, network: network)
        case let .staking(staking):
            self.init(staking: staking, model: model, network: network)
        }
    }

    private init(transfer: TransactionConfirmationModel.Transaction.Transfer, model: TransactionConfirmationModel, network: Network) {
        let category: TransactionSent.Category = .transfer
        let categoryDetail: TransactionSent.CategoryDetail
        let asset: String
        let amount: Float

        switch transfer {
        case .ton:
            categoryDetail = .coin
            asset = KeeperCore.Token.ton(.ton).assetId(network: network)
            amount = model.amount.analyticsAmount
        case let .jetton(jettonInfo):
            categoryDetail = .token
            asset = AssetId.jetton(address: jettonInfo.address, network: network)
            amount = model.amount.analyticsAmount
        case let .nft(nft):
            categoryDetail = .nft
            asset = AssetId.nft(address: nft.address, network: network)
            amount = 1
        case .tronUSDT:
            categoryDetail = .token
            asset = KeeperCore.Token.tron(.usdt).assetId(network: network)
            amount = model.amount.analyticsAmount
        case .tronTRX:
            categoryDetail = .coin
            asset = KeeperCore.Token.tron(.trx).assetId(network: network)
            amount = model.amount.analyticsAmount
        case let .multichain(multichainAsset):
            asset = multichainAsset.asset.assetId
            categoryDetail = asset.analyticsAssetCategoryDetail
            amount = model.amount.analyticsAmount
        }

        self.init(
            category: category,
            categoryDetail: categoryDetail,
            asset: asset,
            amount: amount,
            isMax: model.isMax,
            stakingProvider: nil,
            isLiquid: nil
        )
    }

    private init(staking: TransactionConfirmationModel.Transaction.Staking, model: TransactionConfirmationModel, network: Network) {
        let categoryDetail: TransactionSent.CategoryDetail = {
            switch staking.flow {
            case .deposit:
                return .stake
            case let .withdraw(isCollect):
                return isCollect ? .claim : .unstake
            }
        }()

        self.init(
            category: .staking,
            categoryDetail: categoryDetail,
            asset: KeeperCore.Token.ton(.ton).assetId(network: network),
            amount: model.amount.analyticsAmount,
            isMax: model.isMax,
            stakingProvider: staking.pool.address.toRaw(),
            isLiquid: staking.pool.implementation.type == .liquidTF
        )
    }
}

private extension Optional where Wrapped == TransactionConfirmationModel.Amount {
    var analyticsAmount: Float {
        guard let self else { return 0 }
        return NSDecimalNumber.fromBigUInt(
            value: self.value,
            decimals: self.token.fractionDigits
        ).floatValue
    }
}

private extension String {
    var analyticsChain: String? {
        AssetIdComponents(assetId: self)?.chain.lowercased()
    }

    var analyticsAssetCategoryDetail: TransactionSent.CategoryDetail {
        guard let components = AssetIdComponents(assetId: self) else {
            return .token
        }
        let type = switch components {
        case .coin:
            "coin"
        case let .asset(_, _, type, _):
            type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        switch type {
        case "coin":
            return .coin
        case "nft", "erc721", "erc1155":
            return .nft
        default:
            return .token
        }
    }
}

private struct AnalyticsEmulatedTransactionPayload {
    let category: TransactionSent.Category
    let categoryDetail: TransactionSent.CategoryDetail
    let asset: String
    let amount: Float
    let toAsset: String?
    let stakingProvider: String?
    let isLiquid: Bool?

    private init(
        category: TransactionSent.Category,
        categoryDetail: TransactionSent.CategoryDetail,
        asset: String,
        amount: Float,
        toAsset: String? = nil,
        stakingProvider: String? = nil,
        isLiquid: Bool? = nil
    ) {
        self.category = category
        self.categoryDetail = categoryDetail
        self.asset = asset
        self.amount = amount
        self.toAsset = toAsset
        self.stakingProvider = stakingProvider
        self.isLiquid = isLiquid
    }

    init(emulation: SignRawEmulation, network: Network) {
        let tonAsset = KeeperCore.Token.ton(.ton).assetId(network: network)
        guard emulation.event.actions.count == 1,
              let action = emulation.event.actions.first
        else {
            self.init(category: .call, categoryDetail: .unknown, asset: tonAsset, amount: 0)
            return
        }

        switch action.type {
        case let .tonTransfer(transfer):
            self.init(
                category: .transfer,
                categoryDetail: .coin,
                asset: tonAsset,
                amount: Self.tonAmount(transfer.amount)
            )
        case let .jettonTransfer(transfer):
            self.init(
                category: .transfer,
                categoryDetail: .token,
                asset: Self.jettonAsset(transfer.jettonInfo, network: network),
                amount: NSDecimalNumber.fromBigUInt(
                    value: transfer.amount,
                    decimals: transfer.jettonInfo.fractionDigits
                ).floatValue
            )
        case let .nftItemTransfer(transfer):
            self.init(
                category: .transfer,
                categoryDetail: .nft,
                asset: AssetId.nft(address: transfer.nftAddress, network: network),
                amount: 1
            )
        case .domainRenew:
            self.init(category: .call, categoryDetail: .domainRenew, asset: tonAsset, amount: 0)
        case let .subscribe(subscription):
            self.init(
                category: .call,
                categoryDetail: .subscription,
                asset: tonAsset,
                amount: Self.tonAmount(subscription.amount)
            )
        case .unsubscribe:
            self.init(category: .call, categoryDetail: .subscription, asset: tonAsset, amount: 0)
        case .contractDeploy:
            self.init(category: .call, categoryDetail: .deploy, asset: tonAsset, amount: 0)
        case let .jettonSwap(swap):
            self.init(
                category: .swap,
                categoryDetail: .onchain,
                asset: swap.jettonInfoIn.map { Self.jettonAsset($0, network: network) } ?? tonAsset,
                amount: Self.swapAmount(
                    jetton: swap.jettonInfoIn,
                    jettonValue: swap.amountIn,
                    tonValue: swap.tonIn
                ),
                toAsset: swap.jettonInfoOut.map { Self.jettonAsset($0, network: network) } ?? tonAsset
            )
        case let .depositStake(stake):
            self.init(
                category: .staking,
                categoryDetail: .stake,
                asset: tonAsset,
                amount: Self.tonAmount(stake.amount),
                stakingProvider: stake.pool.address.toRaw(),
                isLiquid: stake.implementation == .liquidTF
            )
        case let .withdrawStakeRequest(request):
            self.init(
                category: .staking,
                categoryDetail: .unstake,
                asset: tonAsset,
                amount: Self.tonAmount(request.amount ?? 0),
                stakingProvider: request.pool.address.toRaw(),
                isLiquid: request.implementation == .liquidTF
            )
        case let .withdrawStake(withdraw):
            self.init(
                category: .staking,
                categoryDetail: .claim,
                asset: tonAsset,
                amount: Self.tonAmount(withdraw.amount),
                stakingProvider: withdraw.pool.address.toRaw(),
                isLiquid: withdraw.implementation == .liquidTF
            )
        case let .smartContractExec(exec):
            self.init(
                category: .call,
                categoryDetail: .unknown,
                asset: tonAsset,
                amount: Self.tonAmount(exec.tonAttached)
            )
        default:
            self.init(category: .call, categoryDetail: .unknown, asset: tonAsset, amount: 0)
        }
    }

    private static func jettonAsset(_ jetton: JettonInfo, network: Network) -> String {
        AssetId.jetton(address: jetton.address, network: network)
    }

    private static func swapAmount(jetton: JettonInfo?, jettonValue: BigUInt, tonValue: Int64?) -> Float {
        guard let jetton else {
            return tonValue.map(tonAmount) ?? 0
        }
        return NSDecimalNumber.fromBigUInt(
            value: jettonValue,
            decimals: jetton.fractionDigits
        ).floatValue
    }

    private static func tonAmount(_ nanotons: Int64) -> Float {
        guard nanotons > 0 else { return 0 }
        return NSDecimalNumber.fromBigUInt(
            value: BigUInt(nanotons),
            decimals: TonInfo.fractionDigits
        ).floatValue
    }
}
