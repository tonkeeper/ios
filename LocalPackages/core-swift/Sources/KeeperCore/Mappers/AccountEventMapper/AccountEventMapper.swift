import BigInt
import Foundation
import TKLocalize
import TonSwift

public struct AccountEventMapper {
    private let dateFormatter: DateFormatter
    private let amountMapper: AccountEventAmountMapper

    public init(
        dateFormatter: DateFormatter,
        amountMapper: AccountEventAmountMapper
    ) {
        self.dateFormatter = dateFormatter
        self.amountMapper = amountMapper
    }

    public init(
        dateFormatter: DateFormatter,
        amountFormatter: AmountFormatter
    ) {
        self.init(
            dateFormatter: dateFormatter,
            amountMapper: SignedAccountEventAmountMapper(amountFormatter: amountFormatter)
        )
    }

    public func mapEvent(
        _ event: AccountEvent,
        nftManagmentStore: WalletNFTsManagementStore,
        transactionManagementStore: TransactionsManagement.Store,
        eventDate: Date,
        accountEventRightTopDescriptionProvider: AccountEventRightTopDescriptionProvider,
        network: Network,
        nftProvider: (Address) -> NFT?,
        decryptedCommentProvider: (_ payload: EncryptedCommentPayload) -> String?
    ) -> AccountEventModel {
        mapEvent(
            event,
            nftManagmentStore: nftManagmentStore,
            eventDate: eventDate,
            accountEventRightTopDescriptionProvider: accountEventRightTopDescriptionProvider,
            network: network,
            transactionManagementStateProvider: { transactionManagementStore.state.states[$0] },
            nftProvider: nftProvider,
            decryptedCommentProvider: decryptedCommentProvider
        )
    }

    public func mapEvent(
        _ event: AccountEvent,
        nftManagmentStore: WalletNFTsManagementStore,
        eventDate: Date,
        accountEventRightTopDescriptionProvider: AccountEventRightTopDescriptionProvider,
        network: Network,
        nftProvider: (Address) -> NFT?,
        decryptedCommentProvider: (_ payload: EncryptedCommentPayload) -> String?
    ) -> AccountEventModel {
        mapEvent(
            event,
            nftManagmentStore: nftManagmentStore,
            eventDate: eventDate,
            accountEventRightTopDescriptionProvider: accountEventRightTopDescriptionProvider,
            network: network,
            transactionManagementStateProvider: { _ in nil },
            nftProvider: nftProvider,
            decryptedCommentProvider: decryptedCommentProvider
        )
    }

    private func mapEvent(
        _ event: AccountEvent,
        nftManagmentStore: WalletNFTsManagementStore,
        eventDate: Date,
        accountEventRightTopDescriptionProvider: AccountEventRightTopDescriptionProvider,
        network: Network,
        transactionManagementStateProvider: (String) -> TransactionsManagement.TransactionState?,
        nftProvider: (Address) -> NFT?,
        decryptedCommentProvider: (_ payload: EncryptedCommentPayload) -> String?
    ) -> AccountEventModel {
        var accountEventRightTopDescriptionProvider = accountEventRightTopDescriptionProvider
        let actions: [AccountEventModel.Action] = event.actions.compactMap { action in
            let rightTopDescription = accountEventRightTopDescriptionProvider.rightTopDescription(
                accountEvent: event,
                action: action
            )
            return mapAction(
                action,
                nftManagmentStore: nftManagmentStore,
                accountEvent: event,
                rightTopDescription: rightTopDescription,
                network: network,
                transactionManagementState: transactionManagementStateProvider(event.eventId),
                nftProvider: nftProvider,
                decryptedCommentProvider: decryptedCommentProvider
            )
        }
        return AccountEventModel(
            eventId: event.eventId,
            actions: actions,
            accountEvent: event,
            date: eventDate
        )
    }
}

private extension AccountEventMapper {
    func mapAction(
        _ action: AccountEventAction,
        nftManagmentStore: WalletNFTsManagementStore,
        accountEvent: AccountEvent,
        rightTopDescription: String?,
        network: Network,
        transactionManagementState: TransactionsManagement.TransactionState?,
        nftProvider: (Address) -> NFT?,
        decryptedCommentProvider: (_ payload: EncryptedCommentPayload) -> String?
    ) -> AccountEventModel.Action? {
        let status: AccountEventStatus = accountEvent.isInProgress ? .ok : action.status

        switch action.type {
        case let .tonTransfer(tonTransfer):
            return mapTonTransferAction(
                tonTransfer,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue,
                network: network,
                transactionManagementState: transactionManagementState,
                decryptedCommentProvider: decryptedCommentProvider
            )
        case let .jettonTransfer(jettonTransfer):
            return mapJettonTransferAction(
                jettonTransfer,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue,
                network: network,
                transactionManagementState: transactionManagementState,
                decryptedCommentProvider: decryptedCommentProvider
            )
        case let .jettonMint(jettonMint):
            return mapJettonMintAction(
                jettonMint,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue
            )
        case let .jettonBurn(jettonBurn):
            return mapJettonBurnAction(
                jettonBurn,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue
            )
        case let .auctionBid(auctionBid):
            return mapAuctionBidAction(
                auctionBid,
                nftManagmentStore: nftManagmentStore,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue,
                network: network
            )
        case let .nftPurchase(nftPurchase):
            return mapNFTPurchaseAction(
                nftPurchase,
                nftManagmentStore: nftManagmentStore,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue,
                network: network
            )
        case let .purchase(purchase):
            return mapPurchaseAction(
                purchase,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue,
                network: network
            )
        case let .contractDeploy(contractDeploy):
            return mapContractDeployAction(
                contractDeploy,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue,
                network: network
            )
        case let .smartContractExec(smartContractExec):
            return mapSmartContractExecAction(
                smartContractExec,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue,
                network: network
            )
        case let .nftItemTransfer(nftItemTransfer):
            return mapItemTransferAction(
                nftItemTransfer,
                nftManagmentStore: nftManagmentStore,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue,
                network: network,
                nftProvider: nftProvider,
                decryptedCommentProvider: decryptedCommentProvider
            )
        case let .depositStake(depositStake):
            return mapDepositStakeAction(
                depositStake,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue
            )
        case let .withdrawStake(withdrawStake):
            return mapWithdrawStakeAction(
                withdrawStake,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue
            )
        case let .withdrawStakeRequest(withdrawStakeRequest):
            return mapWithdrawStakeRequestAction(
                withdrawStakeRequest,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue
            )
        case let .jettonSwap(jettonSwap):
            return mapJettonSwapAction(
                jettonSwap,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue,
                network: network
            )
        case let .domainRenew(domainRenew):
            return mapDomainRenewAction(
                domainRenew,
                accountEvent: accountEvent,
                preview: action.preview,
                rightTopDescription: rightTopDescription,
                status: status.rawValue,
                network: network
            )
        case .unknown:
            return mapUnknownAction(action, rightTopDescription: rightTopDescription)
        default: return nil
        }
    }

    func mapTonTransferAction(
        _ action: AccountEventAction.TonTransfer,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?,
        network: Network,
        transactionManagementState: TransactionsManagement.TransactionState?,
        decryptedCommentProvider: (_ payload: EncryptedCommentPayload) -> String?
    ) -> AccountEventModel.Action {
        let eventType: AccountEventModel.Action.ActionType
        let leftTopDescription: String
        let amountType: AccountEventActionAmountMapperActionType

        if accountEvent.isScam && transactionManagementState != .normal || transactionManagementState == .spam {
            amountType = .income
            eventType = .spam
            leftTopDescription = action.sender.value(network: network)
        } else if action.sender == accountEvent.account {
            amountType = .outcome
            eventType = .sent
            leftTopDescription = action.recipient.value(network: network)
        } else {
            amountType = .income
            eventType = .receieved
            leftTopDescription = action.sender.value(network: network)
        }

        let amount = amountMapper
            .mapAmount(
                amount: BigUInt(integerLiteral: UInt64(abs(action.amount))),
                fractionDigits: TonInfo.fractionDigits,
                type: amountType,
                currency: .TON
            )

        var encryptedComment: AccountEventModel.Action.EncryptedComment?
        if let actionEncryptedComment = action.encryptedComment {
            let payload = EncryptedCommentPayload(
                encryptedComment: actionEncryptedComment,
                senderAddress: action.sender.address
            )
            if let decrypted = decryptedCommentProvider(payload) {
                encryptedComment = .decrypted(decrypted)
            } else {
                encryptedComment = .encrypted(payload)
            }
        }

        return AccountEventModel.Action(
            eventType: eventType,
            amount: amount,
            subamount: nil,
            leftTopDescription: leftTopDescription,
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: action.comment,
            encryptedComment: encryptedComment,
            nft: nil
        )
    }

    func mapJettonTransferAction(
        _ action: AccountEventAction.JettonTransfer,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?,
        network: Network,
        transactionManagementState: TransactionsManagement.TransactionState?,
        decryptedCommentProvider: (_ payload: EncryptedCommentPayload) -> String?
    ) -> AccountEventModel.Action {
        let eventType: AccountEventModel.Action.ActionType
        let leftTopDescription: String?
        let amountType: AccountEventActionAmountMapperActionType
        if accountEvent.isScam && transactionManagementState != .normal
            || transactionManagementState == .spam
            || action.jettonInfo.verification == .blacklist
        {
            eventType = .spam
            leftTopDescription = action.sender?.value(network: network) ?? nil
            amountType = .income
        } else if action.sender == accountEvent.account {
            eventType = .sent
            leftTopDescription = action.recipient?.value(network: network) ?? nil
            amountType = .outcome
        } else {
            eventType = .receieved
            leftTopDescription = action.sender?.value(network: network) ?? nil
            amountType = .income
        }

        let scaledAmount = action.jettonInfo.scaleValue.flatMap {
            BigUInt.mulFixed(action.amount, $0, fractionDigits: action.jettonInfo.fractionDigits)
        } ?? action.amount

        let amount = amountMapper
            .mapAmount(
                amount: scaledAmount,
                fractionDigits: action.jettonInfo.fractionDigits,
                type: amountType,
                symbol: action.jettonInfo.symbol
            )

        var encryptedComment: AccountEventModel.Action.EncryptedComment?
        if let actionEncryptedComment = action.encryptedComment {
            let payload = EncryptedCommentPayload(
                encryptedComment: actionEncryptedComment,
                senderAddress: action.senderAddress
            )
            if let decrypted = decryptedCommentProvider(payload) {
                encryptedComment = .decrypted(decrypted)
            } else {
                encryptedComment = .encrypted(payload)
            }
        }

        return AccountEventModel.Action(
            eventType: eventType,
            amount: amount,
            subamount: nil,
            leftTopDescription: leftTopDescription,
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: action.comment,
            encryptedComment: encryptedComment,
            nft: nil
        )
    }

    func mapJettonMintAction(
        _ action: AccountEventAction.JettonMint,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?
    ) -> AccountEventModel.Action {
        let amount = amountMapper.mapAmount(
            amount: action.amount,
            fractionDigits: action.jettonInfo.fractionDigits,
            type: .income,
            symbol: action.jettonInfo.symbol
        )

        let eventType: AccountEventModel.Action.ActionType = action.jettonInfo.verification == .blacklist ? .spam : .mint

        return AccountEventModel.Action(
            eventType: eventType,
            amount: amount,
            subamount: nil,
            leftTopDescription: action.jettonInfo.name,
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: nil,
            nft: nil
        )
    }

    func mapJettonBurnAction(
        _ action: AccountEventAction.JettonBurn,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?
    ) -> AccountEventModel.Action {
        let amount = amountMapper.mapAmount(
            amount: action.amount,
            fractionDigits: action.jettonInfo.fractionDigits,
            type: .outcome,
            symbol: action.jettonInfo.symbol
        )

        return AccountEventModel.Action(
            eventType: .burn,
            amount: amount,
            subamount: nil,
            leftTopDescription: action.jettonInfo.name,
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: nil,
            nft: nil
        )
    }

    func mapDepositStakeAction(
        _ action: AccountEventAction.DepositStake,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?
    ) -> AccountEventModel.Action {
        let amount = amountMapper.mapAmount(
            amount: BigUInt(integerLiteral: UInt64(abs(action.amount))),
            fractionDigits: TonInfo.fractionDigits,
            type: .outcome,
            currency: .TON
        )

        return AccountEventModel.Action(
            eventType: .depositStake,
            stakingImplementation: action.implementation,
            amount: amount,
            subamount: nil,
            leftTopDescription: action.pool.name,
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: nil,
            nft: nil
        )
    }

    func mapWithdrawStakeAction(
        _ action: AccountEventAction.WithdrawStake,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?
    ) -> AccountEventModel.Action {
        let amount = amountMapper.mapAmount(
            amount: BigUInt(integerLiteral: UInt64(abs(action.amount))),
            fractionDigits: TonInfo.fractionDigits,
            type: .income,
            currency: .TON
        )

        return AccountEventModel.Action(
            eventType: .withdrawStake,
            stakingImplementation: action.implementation,
            amount: amount,
            subamount: nil,
            leftTopDescription: action.pool.name,
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: nil,
            nft: nil
        )
    }

    func mapWithdrawStakeRequestAction(
        _ action: AccountEventAction.WithdrawStakeRequest,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?
    ) -> AccountEventModel.Action {
        let amount = amountMapper.mapAmount(
            amount: BigUInt(integerLiteral: UInt64(abs(action.amount ?? 0))),
            fractionDigits: TonInfo.fractionDigits,
            type: .none,
            currency: .TON
        )

        return AccountEventModel.Action(
            eventType: .withdrawStakeRequest,
            stakingImplementation: action.implementation,
            amount: amount,
            subamount: nil,
            leftTopDescription: action.pool.name,
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: nil,
            nft: nil
        )
    }

    func mapAuctionBidAction(
        _ action: AccountEventAction.AuctionBid,
        nftManagmentStore: WalletNFTsManagementStore,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?,
        network: Network
    ) -> AccountEventModel.Action {
        var eventType: AccountEventModel.Action.ActionType = .bid
        var nftAction: AccountEventModel.Action.ActionNFT?
        if let nft = action.nft {
            let nftState = calculateNFTState(nft, nftManagmentStore: nftManagmentStore)
            nftAction = composeNFTAction(nft, nftState: nftState)

            if nftState == .spam && nft.trust != .whitelist {
                eventType = .spam
            }
        }

        return AccountEventModel.Action(
            eventType: eventType,
            amount: preview.value,
            subamount: nil,
            leftTopDescription: action.bidder.value(network: network),
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: nil,
            nft: nftAction
        )
    }

    func mapNFTPurchaseAction(
        _ action: AccountEventAction.NFTPurchase,
        nftManagmentStore: WalletNFTsManagementStore,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?,
        network: Network
    ) -> AccountEventModel.Action {
        let nftState = calculateNFTState(action.nft, nftManagmentStore: nftManagmentStore)
        let nftAction = composeNFTAction(action.nft, nftState: nftState)

        var eventType: AccountEventModel.Action.ActionType = .nftPurchase
        if nftState == .spam && action.nft.trust != .whitelist {
            eventType = .spam
        }

        let amount = amountMapper
            .mapAmount(
                amount: action.price,
                fractionDigits: TonInfo.fractionDigits,
                type: action.buyer == accountEvent.account ? .outcome : .income,
                currency: .TON
            )

        return AccountEventModel.Action(
            eventType: eventType,
            amount: amount,
            subamount: nil,
            leftTopDescription: action.seller.value(network: network),
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: nil,
            nft: nftAction
        )
    }

    func mapPurchaseAction(
        _ action: AccountEventAction.Purchase,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?,
        network: Network
    ) -> AccountEventModel.Action {
        let fractionDigits = action.amount.decimals

        let amount = amountMapper
            .mapAmount(
                amount: BigUInt(integerLiteral: UInt64(abs(Int64(action.amount.value) ?? 0))),
                fractionDigits: fractionDigits,
                type: .outcome,
                symbol: action.amount.tokenName
            )

        return AccountEventModel.Action(
            eventType: .purchase,
            amount: amount,
            subamount: nil,
            leftTopDescription: preview.description,
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: nil,
            nft: nil
        )
    }

    func mapContractDeployAction(
        _ action: AccountEventAction.ContractDeploy,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?,
        network: Network
    ) -> AccountEventModel.Action {
        let isTestnet = network == .testnet
        return AccountEventModel.Action(
            eventType: .walletInitialized,
            amount: "-",
            subamount: nil,
            leftTopDescription: FriendlyAddress(
                address: action.address,
                testOnly: isTestnet,
                bounceable: false
            ).toShort(),
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: nil,
            nft: nil
        )
    }

    func mapSmartContractExecAction(
        _ action: AccountEventAction.SmartContractExec,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?,
        network: Network
    ) -> AccountEventModel.Action {
        let amount = amountMapper
            .mapAmount(
                amount: BigUInt(integerLiteral: UInt64(abs(action.tonAttached))),
                fractionDigits: TonInfo.fractionDigits,
                type: action.executor == accountEvent.account ? .outcome : .income,
                currency: .TON
            )

        return AccountEventModel.Action(
            eventType: .contractExec,
            amount: amount,
            subamount: nil,
            leftTopDescription: action.contract.value(network: network),
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: nil,
            nft: nil
        )
    }

    func mapItemTransferAction(
        _ action: AccountEventAction.NFTItemTransfer,
        nftManagmentStore: WalletNFTsManagementStore,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?,
        network: Network,
        nftProvider: (Address) -> NFT?,
        decryptedCommentProvider: (_ payload: EncryptedCommentPayload) -> String?
    ) -> AccountEventModel.Action {
        let isTestnet = network == .testnet
        var eventType: AccountEventModel.Action.ActionType
        var leftTopDescription: String?
        if let previewAccount = preview.accounts.first {
            leftTopDescription = previewAccount.address.toFriendly(
                testOnly: isTestnet,
                bounceable: !previewAccount.isWallet
            ).toShort()
        }
        if accountEvent.isScam {
            eventType = .spam
        } else if action.sender == accountEvent.account {
            eventType = .sent
        } else {
            eventType = .receieved
        }

        var nftAction: AccountEventModel.Action.ActionNFT?
        if let nft = nftProvider(action.nftAddress) {
            let nftState = calculateNFTState(nft, nftManagmentStore: nftManagmentStore)
            nftAction = composeNFTAction(nft, nftState: nftState)

            if nftState == .spam && nft.trust != .whitelist {
                eventType = .spam
            }
        }

        var encryptedComment: AccountEventModel.Action.EncryptedComment?
        if let actionEncryptedComment = action.encryptedComment, let sender = action.sender {
            let payload = EncryptedCommentPayload(
                encryptedComment: actionEncryptedComment,
                senderAddress: sender.address
            )
            if let decrypted = decryptedCommentProvider(payload) {
                encryptedComment = .decrypted(decrypted)
            } else {
                encryptedComment = .encrypted(payload)
            }
        }

        return AccountEventModel.Action(
            eventType: eventType,
            amount: "NFT",
            subamount: nil,
            leftTopDescription: leftTopDescription,
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: action.comment,
            encryptedComment: encryptedComment,
            nft: nftAction
        )
    }

    func mapJettonSwapAction(
        _ action: AccountEventAction.JettonSwap,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?,
        network: Network
    ) -> AccountEventModel.Action {
        let outAmount: String? = {
            let amount: BigUInt
            let fractionDigits: Int
            let symbol: String?
            if let tonOut = action.tonOut {
                amount = BigUInt(integerLiteral: UInt64(abs(tonOut)))
                fractionDigits = TonInfo.fractionDigits
                symbol = TonInfo.symbol
            } else if let jettonInfoOut = action.jettonInfoOut {
                amount = jettonInfoOut.scaleValue.flatMap {
                    BigUInt.mulFixed(action.amountOut, $0, fractionDigits: jettonInfoOut.fractionDigits)
                } ?? action.amountOut
                fractionDigits = jettonInfoOut.fractionDigits
                symbol = jettonInfoOut.symbol
            } else {
                return nil
            }

            return amountMapper
                .mapAmount(
                    amount: amount,
                    fractionDigits: fractionDigits,
                    type: .income,
                    symbol: symbol
                )
        }()

        let inAmount: String? = {
            let amount: BigUInt
            let fractionDigits: Int
            let symbol: String?
            if let tonIn = action.tonIn {
                amount = BigUInt(integerLiteral: UInt64(abs(tonIn)))
                fractionDigits = TonInfo.fractionDigits
                symbol = TonInfo.symbol
            } else if let jettonInfoIn = action.jettonInfoIn {
                amount = jettonInfoIn.scaleValue.flatMap {
                    BigUInt.mulFixed(action.amountIn, $0, fractionDigits: jettonInfoIn.fractionDigits)
                } ?? action.amountIn
                fractionDigits = jettonInfoIn.fractionDigits
                symbol = jettonInfoIn.symbol
            } else {
                return nil
            }
            return amountMapper
                .mapAmount(
                    amount: amount,
                    fractionDigits: fractionDigits,
                    type: .outcome,
                    symbol: symbol
                )
        }()

        return AccountEventModel.Action(
            eventType: .jettonSwap,
            amount: outAmount,
            subamount: inAmount,
            leftTopDescription: action.user.value(network: network),
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: nil,
            nft: nil
        )
    }

    func mapDomainRenewAction(
        _ action: AccountEventAction.DomainRenew,
        accountEvent: AccountEvent,
        preview: AccountEventAction.SimplePreview,
        rightTopDescription: String?,
        status: String?,
        network: Network
    ) -> AccountEventModel.Action {
        return AccountEventModel.Action(
            eventType: .domainRenew,
            amount: action.domain,
            subamount: nil,
            leftTopDescription: preview.accounts.first?.address.toShortString(bounceable: true),
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: nil,
            description: preview.description,
            nft: nil
        )
    }

    func mapUnknownAction(_ action: AccountEventAction, rightTopDescription: String?) -> AccountEventModel.Action {
        return AccountEventModel.Action(
            eventType: .unknown,
            customName: action.preview.name,
            amount: action.preview.value,
            subamount: nil,
            leftTopDescription: action.preview.description,
            leftBottomDescription: nil,
            rightTopDescription: rightTopDescription,
            status: action.status.rawValue,
            comment: nil,
            nft: nil
        )
    }

    private func calculateNFTState(_ nft: NFT, nftManagmentStore: WalletNFTsManagementStore) -> NFTsManagementState.NFTState? {
        if let collection = nft.collection {
            return nftManagmentStore.getState().nftStates[.collection(collection.address)]
        } else {
            return nftManagmentStore.getState().nftStates[.singleItem(nft.address)]
        }
    }

    func composeNFTAction(_ nft: NFT, nftState: NFTsManagementState.NFTState?) -> AccountEventModel.Action.ActionNFT? {
        func composeCollectionName() -> String? {
            if let collection = nft.collection {
                return (collection.name == nil || collection.name?.isEmpty == true) ? TKLocales.NftDetails.singleNft : collection.name
            } else {
                return TKLocales.NftDetails.singleNft
            }
        }

        let collectionName: String?
        let isSuspecious: Bool
        switch nft.trust {
        case .none, .blacklist, .unknown:
            isSuspecious = nftState != .approved
            collectionName = TKLocales.NftDetails.unverifiedNft
        case .whitelist, .graylist:
            collectionName = composeCollectionName()
            isSuspecious = false
        }

        let actionNFT: AccountEventModel.Action.ActionNFT?
        if nft.trust != .whitelist, nftState == .spam {
            actionNFT = nil
        } else {
            actionNFT = AccountEventModel.Action.ActionNFT(
                nft: nft,
                isSuspecious: isSuspecious,
                name: nft.name,
                collectionName: collectionName,
                image: nft.preview.size500
            )
        }
        return actionNFT
    }
}

private extension WalletAccount {
    func value(network: Network) -> String {
        if let name = name { return name }
        let friendlyAddress = FriendlyAddress(
            address: address,
            testOnly: network == .testnet,
            bounceable: !isWallet
        )
        return friendlyAddress.toShort()
    }
}
