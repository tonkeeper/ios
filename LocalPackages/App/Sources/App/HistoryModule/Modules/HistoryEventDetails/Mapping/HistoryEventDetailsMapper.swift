import BigInt
import Foundation
import KeeperCore
import TKLocalize
import TonSwift

final class HistoryEventDetailsMapper {
    private let wallet: Wallet
    private let amountFormatter: AmountFormatter
    private let signedAmountFormatter: AmountFormatter
    private let balanceStore: BalanceStore
    private let tonRatesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let nftService: NFTService
    private let nftManagmentStore: WalletNFTsManagementStore
    private let transactionsManagementStore: TransactionsManagement.Store
    private let tonviewerURLBuilder: TonviewerURLBuilder
    private let network: Network
    private let configuration: Configuration

    private let rateConverter = RateConverter()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter
    }()

    init(
        wallet: Wallet,
        amountFormatter: AmountFormatter,
        signedAmountFormatter: AmountFormatter,
        balanceStore: BalanceStore,
        tonRatesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        nftService: NFTService,
        nftManagmentStore: WalletNFTsManagementStore,
        transactionsManagementStore: TransactionsManagement.Store,
        tonviewerURLBuilder: TonviewerURLBuilder,
        network: Network,
        configuration: Configuration
    ) {
        self.wallet = wallet
        self.amountFormatter = amountFormatter
        self.signedAmountFormatter = signedAmountFormatter
        self.balanceStore = balanceStore
        self.tonRatesStore = tonRatesStore
        self.currencyStore = currencyStore
        self.nftService = nftService
        self.nftManagmentStore = nftManagmentStore
        self.transactionsManagementStore = transactionsManagementStore
        self.tonviewerURLBuilder = tonviewerURLBuilder
        self.network = network
        self.configuration = configuration
    }

    func mapEvent(
        event: AccountEventDetailsEvent,
        decryptedCommentProvider: (_ eventId: String, _ payload: EncryptedCommentPayload) -> String?
    ) -> HistoryEventDetailsModel {
        let isTestnet = network == .testnet
        let eventAction = event.action
        let date = dateFormatter.string(from: event.accountEvent.date)

        let extraUInt = {
            switch event.accountEvent.extra {
            case let .Fee(fee):
                return fee
            case let .Refund(refund):
                return refund
            }
        }()

        let extra = amountFormatter.format(
            amount: BigUInt(integerLiteral: extraUInt),
            fractionDigits: TonInfo.fractionDigits,
            accessory: .currency(Currency.TON)
        )
        let extraConverted = isTestnet ? nil : convertTonToFiatString(amount: BigUInt(extraUInt))

        var isRefund = false
        if case .Refund = event.accountEvent.extra {
            isRefund = true
        }

        let status: AccountEventStatus = event.accountEvent.isInProgress ? .ok : eventAction.status

        let detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton? = {
            let transaction = TKLocales.EventDetails.transaction.withTextStyle(.label2, color: .Text.primary)
            let hash = String(event.accountEvent.eventId.prefix(8)).withTextStyle(.label2, color: .Text.secondary)
            let title = NSMutableAttributedString(attributedString: transaction)
            title.append(hash)
            guard let url = tonviewerURLBuilder.buildURL(context: .eventDetails(eventID: event.accountEvent.eventId), network: network) else {
                return nil
            }

            return HistoryEventDetailsModel.TransasctionDetailsButton(
                buttonTitle: title,
                url: url,
                browserTitle: "Tonviewer",
                hash: event.accountEvent.eventId
            )
        }()

        switch eventAction.type {
        case let .tonTransfer(tonTransfer):
            return mapTonTransfer(
                activityEvent: event.accountEvent,
                tonTransfer: tonTransfer,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton,
                network: network,
                decryptedCommentProvider: decryptedCommentProvider
            )
        case let .jettonTransfer(jettonTransfer):
            return mapJettonTransfer(
                activityEvent: event.accountEvent,
                action: jettonTransfer,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton,
                network: network,
                isNetworkBadgeVisible: wallet.isTronTurnOn && jettonTransfer.jettonInfo.isTonUSDT,
                decryptedCommentProvider: decryptedCommentProvider
            )
        case let .nftItemTransfer(nftItemTransfer):
            return mapNFTTransfer(
                activityEvent: event.accountEvent,
                nftTransfer: nftItemTransfer,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton,
                network: network,
                decryptedCommentProvider: decryptedCommentProvider
            )
        case let .nftPurchase(nftPurchase):
            return mapNFTPurchase(
                activityEvent: event.accountEvent,
                action: nftPurchase,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton,
                network: network
            )
        case let .purchase(purchase):
            return mapPurchaseAction(
                activityEvent: event.accountEvent,
                action: purchase,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton,
                network: network
            )
        case let .domainRenew(domainRenew):
            return mapDomainRenew(
                activityEvent: event.accountEvent,
                action: domainRenew,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                description: eventAction.preview.description,
                detailsButton: detailsButton
            )
        case let .contractDeploy(contractDeploy):
            return mapContractDeploy(
                activityEvent: event.accountEvent,
                action: contractDeploy,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton
            )
        case let .jettonBurn(jettonBurn):
            return mapJettonBurn(
                activityEvent: event.accountEvent,
                action: jettonBurn,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton
            )
        case let .jettonMint(jettonMint):
            return mapJettonMint(
                activityEvent: event.accountEvent,
                action: jettonMint,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton,
                network: network
            )
        case let .jettonSwap(jettonSwap):
            return mapJettonSwap(
                activityEvent: event.accountEvent,
                action: jettonSwap,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton,
                network: network
            )
        case let .auctionBid(auctionBid):
            return mapAuctionBid(
                activityEvent: event.accountEvent,
                action: auctionBid,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton
            )
        case let .depositStake(depositStake):
            return mapDepositStake(
                activityEvent: event.accountEvent,
                action: depositStake,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton,
                network: network
            )
        case let .smartContractExec(smartContractExec):
            return mapSmartContractExec(
                activityEvent: event.accountEvent,
                smartContractExec: smartContractExec,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton,
                network: network
            )
        case let .withdrawStake(withdrawStake):
            return mapWithdrawStake(
                activityEvent: event.accountEvent,
                action: withdrawStake,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton,
                network: network
            )
        case let .withdrawStakeRequest(withdrawStakeRequest):
            return mapWithdrawStakeRequest(
                activityEvent: event.accountEvent,
                action: withdrawStakeRequest,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                status: status,
                detailsButton: detailsButton,
                network: network
            )
        default:
            return mapUnknownAction(
                simplePreview: event.action.preview,
                date: date,
                extra: extra,
                extraConverted: extraConverted,
                isRefund: isRefund,
                detailsButton: detailsButton
            )
        }
    }

    private enum TransferDirection {
        case send
        case receive
    }

    private func mapTonTransfer(
        activityEvent: AccountEvent,
        tonTransfer: AccountEventAction.TonTransfer,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?,
        network: Network,
        decryptedCommentProvider: (_ eventId: String, _ payload: EncryptedCommentPayload) -> String?
    ) -> HistoryEventDetailsModel {
        let isTestnet = network == .testnet
        let transferDirection: TransferDirection = {
            if tonTransfer.sender == activityEvent.account {
                return .send
            } else {
                return .receive
            }
        }()

        var listItems = [HistoryEventDetailsModel.ListItem]()
        let dateFormatted: String
        let amountType: AccountEventActionAmountMapperActionType

        switch transferDirection {
        case .send:
            dateFormatted = TKLocales.EventDetails.sentOn(date)
            amountType = .outcome
            if let name = tonTransfer.recipient.name {
                listItems.append(.recipient(value: name, copyValue: name))
            }
            listItems.append(
                .recipientAddress(
                    value: tonTransfer.recipient.address.toString(testOnly: isTestnet, bounceable: !tonTransfer.recipient.isWallet),
                    copyValue: tonTransfer.recipient.address.toString(testOnly: isTestnet, bounceable: !tonTransfer.recipient.isWallet)
                )
            )
        case .receive:
            dateFormatted = TKLocales.EventDetails.receivedOn(date)
            amountType = .income
            if let name = tonTransfer.sender.name {
                listItems.append(.sender(value: name, copyValue: name))
            }
            listItems.append(
                .senderAddress(
                    value: tonTransfer.sender.address.toString(testOnly: isTestnet, bounceable: !tonTransfer.sender.isWallet),
                    copyValue: tonTransfer.sender.address.toString(testOnly: isTestnet, bounceable: !tonTransfer.sender.isWallet)
                )
            )
        }
        listItems.append(.extra(value: extra, isRefund: isRefund, converted: extraConverted))
        if let comment = tonTransfer.comment, !comment.isEmpty, !activityEvent.isScam {
            listItems.append(.comment(comment))
        }
        if let encryptedComment = tonTransfer.encryptedComment {
            listItems.append(
                createEncryptedCommentListItem(
                    encryptedComment: encryptedComment,
                    eventId: activityEvent.eventId,
                    senderAddress: tonTransfer.sender.address,
                    decryptedCommentProvider: decryptedCommentProvider
                )
            )
        }

        let tonAmount = UInt64(abs(tonTransfer.amount))

        let title = signedAmountFormatter.format(
            amount: BigUInt(integerLiteral: tonAmount),
            fractionDigits: TonInfo.fractionDigits,
            accessory: .currency(Currency.TON),
            isNegative: amountType == .outcome,
            style: .exactValue
        )

        let fiatPrice = isTestnet ? nil : convertTonToFiatString(amount: BigUInt(tonTransfer.amount))
        let isScam = activityEvent.isScam && transactionsManagementStore.state.states[activityEvent.eventId] != .normal || transactionsManagementStore.state.states[activityEvent.eventId] == .spam
        let management: HistoryEventDetailsModel.Management? = {
            guard transferDirection == .receive else { return nil }
            let isManagementAvailable: Bool = {
                let compareResult = NSDecimalNumber(value: tonAmount)
                    .compare(configuration.reportAmount(network: network).multiplying(byPowerOf10: Int16(TonInfo.fractionDigits)))
                if compareResult == .orderedAscending || compareResult == .orderedSame {
                    return true
                } else {
                    return false
                }
            }()
            return HistoryEventDetailsModel.Management(
                state: transactionsManagementStore.state.states[activityEvent.eventId],
                isManagementAvailable: isManagementAvailable
            )
        }()
        return HistoryEventDetailsModel(
            headerImage: .transfer(
                TransactionConfirmationHeaderImageItem(
                    configuration: TransactionConfirmationHeaderImageItemView.Configuration(
                        image: .image(.App.Currency.Vector.ton),
                        corners: .circle,
                        badge: nil
                    ),
                    bottomSpace: 20
                )
            ),
            title: title,
            date: dateFormatted,
            fiatPrice: fiatPrice,
            warningText: status.rawValue,
            isScam: isScam,
            management: management,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    func mapJettonTransfer(
        activityEvent: AccountEvent,
        action: AccountEventAction.JettonTransfer,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?,
        network: Network,
        isNetworkBadgeVisible: Bool,
        decryptedCommentProvider: (_ eventId: String, _ payload: EncryptedCommentPayload) -> String?
    ) -> HistoryEventDetailsModel {
        let isTestnet = network == .testnet
        let transferDirection: TransferDirection = {
            if action.sender == activityEvent.account {
                return .send
            } else {
                return .receive
            }
        }()

        var listItems = [HistoryEventDetailsModel.ListItem]()
        let dateFormatted: String
        let amountType: AccountEventActionAmountMapperActionType

        switch transferDirection {
        case .send:
            dateFormatted = TKLocales.EventDetails.sentOn(date)
            amountType = .outcome
            if let recipient = action.recipient {
                if let name = recipient.name {
                    listItems.append(.recipient(value: name, copyValue: name))
                }
                listItems.append(
                    .recipientAddress(
                        value: recipient.address.toString(testOnly: isTestnet, bounceable: !recipient.isWallet),
                        copyValue: recipient.address.toString(testOnly: isTestnet, bounceable: !recipient.isWallet)
                    )
                )
            }
        case .receive:
            dateFormatted = TKLocales.EventDetails.receivedOn(date)
            amountType = .income
            if let sender = action.sender {
                if let name = sender.name {
                    listItems.append(.sender(value: name, copyValue: name))
                }
                listItems.append(
                    .senderAddress(
                        value: sender.address.toString(testOnly: isTestnet, bounceable: !sender.isWallet),
                        copyValue: sender.address.toString(testOnly: isTestnet, bounceable: !sender.isWallet)
                    )
                )
            }
        }
        listItems.append(.extra(value: extra, isRefund: isRefund, converted: extraConverted))
        if let comment = action.comment, !comment.isEmpty, !activityEvent.isScam {
            listItems.append(.comment(comment))
        }
        if let encryptedComment = action.encryptedComment, !activityEvent.isScam {
            listItems.append(
                createEncryptedCommentListItem(
                    encryptedComment: encryptedComment,
                    eventId: activityEvent.eventId,
                    senderAddress: action.senderAddress,
                    decryptedCommentProvider: decryptedCommentProvider
                )
            )
        }

        let jettonAmount = action.jettonInfo.scaleValue.flatMap {
            BigUInt.mulFixed(action.amount, $0, fractionDigits: action.jettonInfo.fractionDigits)
        } ?? action.amount

        let title = signedAmountFormatter.format(
            amount: jettonAmount,
            fractionDigits: action.jettonInfo.fractionDigits,
            accessory: action.jettonInfo.symbol.flatMap { .symbol($0) } ?? .none,
            isNegative: amountType == .outcome,
            style: .exactValue
        )

        let fiatPrice = jettonFiatString(amount: action.amount, jettonInfo: action.jettonInfo)

        var badge: TransactionConfirmationHeaderImageItemView.Configuration.Badge?
        if isNetworkBadgeVisible {
            badge = TransactionConfirmationHeaderImageItemView.Configuration.Badge(
                image: .image(.App.Currency.Vector.ton)
            )
        }

        var headerImage: HistoryEventDetailsModel.HeaderImage?
        if let imageUrl = action.jettonInfo.imageURL {
            headerImage = .transfer(
                TransactionConfirmationHeaderImageItem(
                    configuration: TransactionConfirmationHeaderImageItemView.Configuration(
                        image: .urlImage(imageUrl),
                        corners: .circle,
                        badge: badge
                    ),
                    bottomSpace: 20
                )
            )
        }

        let isScam = activityEvent.isScam || transactionsManagementStore.state.states[activityEvent.eventId] == .spam

        let management: HistoryEventDetailsModel.Management? = {
            guard transferDirection == .receive else { return nil }
            let isManagementAvailable: Bool = {
                guard let balance = balanceStore.state[wallet]?.walletBalance.balance.jettonsBalance
                    .first(where: { $0.item.jettonInfo == action.jettonInfo })
                else {
                    return false
                }
                guard let rate = balance.rates.first(where: { $0.key == .TON })?.value else {
                    return false
                }
                let tonAmount = RateConverter().convertToDecimal(
                    amount: action.amount,
                    amountFractionLength: balance.item.jettonInfo.fractionDigits,
                    rate: rate
                )

                let compareResult = NSDecimalNumber(decimal: tonAmount)
                    .compare(configuration.reportAmount(network: network).multiplying(byPowerOf10: Int16(TonInfo.fractionDigits)))
                if compareResult == .orderedAscending || compareResult == .orderedSame {
                    return true
                } else {
                    return false
                }
            }()
            return HistoryEventDetailsModel.Management(
                state: transactionsManagementStore.state.states[activityEvent.eventId],
                isManagementAvailable: isManagementAvailable
            )
        }()

        return HistoryEventDetailsModel(
            headerImage: headerImage,
            title: title,
            date: dateFormatted,
            fiatPrice: fiatPrice,
            warningText: warningText(for: action.jettonInfo, status: status),
            isScam: isScam,
            management: management,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    func mapNFTTransfer(
        activityEvent: AccountEvent,
        nftTransfer: AccountEventAction.NFTItemTransfer,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?,
        network: Network,
        decryptedCommentProvider: (_ eventId: String, _ payload: EncryptedCommentPayload) -> String?
    ) -> HistoryEventDetailsModel {
        let isTestnet = network == .testnet

        let transferDirection: TransferDirection = {
            if nftTransfer.sender == activityEvent.account {
                return .send
            } else {
                return .receive
            }
        }()

        var listItems = [HistoryEventDetailsModel.ListItem]()
        let dateFormatted: String

        switch transferDirection {
        case .send:
            dateFormatted = TKLocales.EventDetails.sentOn(date)
            if let recipient = nftTransfer.recipient {
                if let name = recipient.name {
                    listItems.append(.recipient(value: name, copyValue: name))
                }
                listItems.append(
                    .recipientAddress(
                        value: recipient.address.toString(testOnly: isTestnet, bounceable: !recipient.isWallet),
                        copyValue: recipient.address.toString(testOnly: isTestnet, bounceable: !recipient.isWallet)
                    )
                )
            }
        case .receive:
            dateFormatted = TKLocales.EventDetails.receivedOn(date)
            if let sender = nftTransfer.sender {
                if let name = sender.name {
                    listItems.append(.sender(value: name, copyValue: name))
                }
                listItems.append(
                    .senderAddress(
                        value: sender.address.toString(testOnly: isTestnet, bounceable: !sender.isWallet),
                        copyValue: sender.address.toString(testOnly: isTestnet, bounceable: !sender.isWallet)
                    )
                )
            }
        }

        let nft = try? nftService.getNFT(address: nftTransfer.nftAddress, network: network)
        guard let nft, nft.trust != .blacklist else {
            return HistoryEventDetailsModel(
                title: "NFT",
                date: dateFormatted,
                warningText: status.rawValue,
                isScam: activityEvent.isScam,
                listItems: [.extra(value: extra, isRefund: isRefund, converted: extraConverted)],
                detailsButton: detailsButton
            )
        }

        let nftState = calculateNFTState(nft, nftManagmentStore: nftManagmentStore)
        let isScam = activityEvent.isScam || nftState == .spam
        listItems.append(.extra(value: extra, isRefund: isRefund, converted: extraConverted))
        if let comment = nftTransfer.comment, !comment.isEmpty, !isScam {
            listItems.append(.comment(comment))
        }
        if let encryptedComment = nftTransfer.encryptedComment, let sender = nftTransfer.sender {
            listItems.append(
                createEncryptedCommentListItem(
                    encryptedComment: encryptedComment,
                    eventId: activityEvent.eventId,
                    senderAddress: sender.address,
                    decryptedCommentProvider: decryptedCommentProvider
                )
            )
        }

        var headerImage: HistoryEventDetailsModel.HeaderImage?
        if let nftImageUrl = nft.imageURL {
            headerImage = .transfer(
                TransactionConfirmationHeaderImageItem(
                    configuration: TransactionConfirmationHeaderImageItemView.Configuration(
                        image: .urlImage(nftImageUrl),
                        corners: .cornerRadius(cornerRadius: 12),
                        badge: nil
                    ),
                    bottomSpace: 20
                )
            )
        }
        let nftModel = HistoryEventDetailsModel.NFT(
            name: nft.name,
            collectionName: nft.collection?.name,
            isVerified: nft.trust == .whitelist
        )

        return HistoryEventDetailsModel(
            headerImage: headerImage,
            title: "NFT",
            date: dateFormatted,
            nftModel: nftModel,
            warningText: warningText(for: nft, status: status),
            isScam: isScam,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    func mapNFTPurchase(
        activityEvent: AccountEvent,
        action: AccountEventAction.NFTPurchase,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?,
        network: Network
    ) -> HistoryEventDetailsModel {
        let isTestnet = network == .testnet
        var listItems = [HistoryEventDetailsModel.ListItem]()
        let dateFormatted = TKLocales.EventDetails.purchasedOn(date)

        if let sender = action.seller.name {
            listItems.append(.sender(value: sender, copyValue: sender))
        }
        listItems.append(.senderAddress(
            value: action.seller.address.toString(testOnly: isTestnet, bounceable: !action.seller.isWallet),
            copyValue: action.seller.address.toString(testOnly: isTestnet, bounceable: !action.seller.isWallet)
        ))

        listItems.append(.extra(value: extra, isRefund: isRefund, converted: extraConverted))

        var headerImage: HistoryEventDetailsModel.HeaderImage?
        if let nftImageUrl = action.nft.imageURL {
            headerImage = .transfer(
                TransactionConfirmationHeaderImageItem(
                    configuration: TransactionConfirmationHeaderImageItemView.Configuration(
                        image: .urlImage(nftImageUrl),
                        corners: .cornerRadius(cornerRadius: 12),
                        badge: nil
                    ),
                    bottomSpace: 20
                )
            )
        }

        let nftModel = HistoryEventDetailsModel.NFT(
            name: action.nft.name,
            collectionName: action.nft.collection?.name,
            isVerified: action.nft.trust == .whitelist
        )

        let title = signedAmountFormatter.format(
            amount: action.price,
            fractionDigits: TonInfo.fractionDigits,
            accessory: .currency(Currency.TON),
            isNegative: true,
            style: .exactValue
        )

        let fiatPrice = convertTonToFiatString(amount: action.price)
        let nftState = calculateNFTState(action.nft, nftManagmentStore: nftManagmentStore)
        let isScam = activityEvent.isScam || nftState == .spam
        return HistoryEventDetailsModel(
            headerImage: headerImage,
            title: title,
            date: dateFormatted,
            fiatPrice: fiatPrice,
            nftModel: nftModel,
            warningText: warningText(for: action.nft, status: status),
            isScam: isScam,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    private func mapPurchaseAction(
        activityEvent: AccountEvent,
        action: AccountEventAction.Purchase,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?,
        network: Network
    ) -> HistoryEventDetailsModel {
        let fractionDigits: Int = action.amount.decimals

        let title = signedAmountFormatter.format(
            amount: BigUInt(integerLiteral: UInt64(abs(Int32(action.amount.value) ?? 0))),
            fractionDigits: fractionDigits,
            accessory: .symbol(action.amount.tokenName),
            isNegative: true,
            style: .exactValue
        )

        let headerImage: HistoryEventDetailsModel.HeaderImage? = .transfer(
            TransactionConfirmationHeaderImageItem(
                configuration: TransactionConfirmationHeaderImageItemView.Configuration(
                    image: .urlImage(URL(string: action.amount.image)),
                    corners: .circle,
                    badge: nil
                ),
                bottomSpace: 20
            )
        )

        return HistoryEventDetailsModel(
            headerImage: headerImage,
            title: title,
            aboveTitle: TKLocales.ActionTypes.purchase,
            date: date,
            fiatPrice: nil,
            nftModel: nil,
            warningText: nil,
            isScam: action.source.isScam,
            listItems: [],
            detailsButton: detailsButton
        )
    }

    private func calculateNFTState(_ nft: NFT, nftManagmentStore: WalletNFTsManagementStore) -> NFTsManagementState.NFTState? {
        if let collection = nft.collection {
            return nftManagmentStore.getState().nftStates[.collection(collection.address)]
        } else {
            return nftManagmentStore.getState().nftStates[.singleItem(nft.address)]
        }
    }

    func mapDomainRenew(
        activityEvent: AccountEvent,
        action: AccountEventAction.DomainRenew,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        description: String,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?
    ) -> HistoryEventDetailsModel {
        let title = action.domain
        let dateFormatted = TKLocales.EventDetails.renewedOn(date)

        var listItems: [HistoryEventDetailsModel.ListItem] = [
            .operation(TKLocales.EventDetails.domainRenew),
        ]
        if !description.isEmpty {
            listItems.append(.description(description))
        }

        listItems.append(.extra(value: extra, isRefund: isRefund, converted: extraConverted))

        return HistoryEventDetailsModel(
            title: title,
            date: dateFormatted,
            warningText: status.rawValue,
            isScam: activityEvent.isScam,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    func mapJettonBurn(
        activityEvent: AccountEvent,
        action: AccountEventAction.JettonBurn,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?
    ) -> HistoryEventDetailsModel {
        let title = signedAmountFormatter.format(
            amount: action.amount,
            fractionDigits: action.jettonInfo.fractionDigits,
            accessory: action.jettonInfo.symbol.flatMap { .symbol($0) } ?? .none,
            isNegative: true,
            style: .exactValue
        )

        let dateString = "Burned on \(date)"
        let fiatPrice = jettonFiatString(amount: action.amount, jettonInfo: action.jettonInfo)

        var headerImage: HistoryEventDetailsModel.HeaderImage?
        if let imageUrl = action.jettonInfo.imageURL {
            headerImage = .transfer(
                TransactionConfirmationHeaderImageItem(
                    configuration: TransactionConfirmationHeaderImageItemView.Configuration(
                        image: .urlImage(imageUrl),
                        corners: .circle,
                        badge: nil
                    ),
                    bottomSpace: 20
                )
            )
        }

        return HistoryEventDetailsModel(
            headerImage: headerImage,
            title: title,
            aboveTitle: nil,
            date: dateString,
            fiatPrice: fiatPrice,
            warningText: warningText(for: action.jettonInfo, status: status),
            isScam: activityEvent.isScam,
            listItems: [.extra(value: extra, isRefund: isRefund, converted: extraConverted)],
            detailsButton: detailsButton
        )
    }

    func mapJettonMint(
        activityEvent: AccountEvent,
        action: AccountEventAction.JettonMint,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?,
        network: Network
    ) -> HistoryEventDetailsModel {
        let isTestnet = network == .testnet
        let title = signedAmountFormatter.format(
            amount: action.amount,
            fractionDigits: action.jettonInfo.fractionDigits,
            accessory: action.jettonInfo.symbol.flatMap { .symbol($0) } ?? .none,
            style: .exactValue
        )
        let dateString = TKLocales.EventDetails.receivedOn(date)
        let fiatPrice = jettonFiatString(amount: action.amount, jettonInfo: action.jettonInfo)
        var listItems = [HistoryEventDetailsModel.ListItem]()
        if let recipient = action.recipient.name {
            listItems.append(.recipient(value: recipient, copyValue: recipient))
        }
        listItems.append(
            .recipientAddress(
                value: action.recipient.address.toString(testOnly: isTestnet, bounceable: !action.recipient.isWallet),
                copyValue: action.recipient.address.toString(testOnly: isTestnet, bounceable: !action.recipient.isWallet)
            )
        )
        listItems.append(.extra(value: extra, isRefund: isRefund, converted: extraConverted))

        var headerImage: HistoryEventDetailsModel.HeaderImage?
        if let imageUrl = action.jettonInfo.imageURL {
            headerImage = .transfer(
                TransactionConfirmationHeaderImageItem(
                    configuration: TransactionConfirmationHeaderImageItemView.Configuration(
                        image: .urlImage(imageUrl),
                        corners: .circle,
                        badge: nil
                    ),
                    bottomSpace: 20
                )
            )
        }

        return HistoryEventDetailsModel(
            headerImage: headerImage,
            title: title,
            aboveTitle: nil,
            date: dateString,
            fiatPrice: fiatPrice,
            warningText: warningText(for: action.jettonInfo, status: status),
            isScam: activityEvent.isScam,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    func mapJettonSwap(
        activityEvent: AccountEvent,
        action: AccountEventAction.JettonSwap,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?,
        network: Network
    ) -> HistoryEventDetailsModel {
        let isTestnet = network == .testnet
        let title: String? = {
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

            return signedAmountFormatter.format(
                amount: amount,
                fractionDigits: fractionDigits,
                accessory: symbol.flatMap { .symbol($0) } ?? .none
            )
        }()

        let aboveTitle: String? = {
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

            return signedAmountFormatter.format(
                amount: amount,
                fractionDigits: fractionDigits,
                accessory: symbol.flatMap { .symbol($0) } ?? .none,
                isNegative: true
            )
        }()

        let dateString = TKLocales.EventDetails.swappedOn(date)

        var listItems = [HistoryEventDetailsModel.ListItem]()
        listItems.append(
            .recipientAddress(
                value: action.user.address.toString(testOnly: isTestnet, bounceable: !action.user.isWallet),
                copyValue: action.user.address.toString(testOnly: isTestnet, bounceable: !action.user.isWallet)
            )
        )
        listItems.append(.extra(value: extra, isRefund: isRefund, converted: extraConverted))

        let headerImage: HistoryEventDetailsModel.HeaderImage = {
            let fromImage: TokenImage
            if let _ = action.tonIn {
                fromImage = .ton
            } else if let jettonInfoIn = action.jettonInfoIn {
                fromImage = .url(jettonInfoIn.imageURL)
            } else {
                fromImage = .ton
            }

            let toImage: TokenImage
            if let _ = action.tonOut {
                toImage = .ton
            } else if let jettonInfoOut = action.jettonInfoOut {
                toImage = .url(jettonInfoOut.imageURL)
            } else {
                toImage = .ton
            }

            return .swap(fromImage: fromImage, toImage: toImage)
        }()

        return HistoryEventDetailsModel(
            headerImage: headerImage,
            title: title,
            aboveTitle: aboveTitle,
            date: dateString,
            fiatPrice: nil,
            warningText: warningTextForSwap(
                jettonIn: action.jettonInfoIn,
                jettonOut: action.jettonInfoOut,
                status: status
            ),
            isScam: activityEvent.isScam,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    func mapAuctionBid(
        activityEvent: AccountEvent,
        action: AccountEventAction.AuctionBid,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?
    ) -> HistoryEventDetailsModel {
        var title: String?
        var fiatPrice: String?
        if action.price.tokenName == "TON" {
            title = signedAmountFormatter.format(
                amount: action.price.amount,
                fractionDigits: TonInfo.fractionDigits,
                accessory: .currency(Currency.TON),
                isNegative: true,
                style: .exactValue
            )
            fiatPrice = convertTonToFiatString(amount: action.price.amount)
        }
        let dateString = "Bid on \(date)"
        var listItems = [HistoryEventDetailsModel.ListItem]()

        if let name = action.nft?.name {
            listItems.append(.other(title: "Name", value: name, copyValue: name))
        }
        if let issuer = action.nft?.collection?.name {
            listItems.append(.other(title: "Issuer", value: issuer, copyValue: issuer))
        }
        listItems.append(.extra(value: extra, isRefund: isRefund, converted: extraConverted))

        return HistoryEventDetailsModel(
            title: title,
            date: dateString,
            fiatPrice: fiatPrice,
            warningText: status.rawValue,
            isScam: activityEvent.isScam,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    func mapDepositStake(
        activityEvent: AccountEvent,
        action: AccountEventAction.DepositStake,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?,
        network: Network
    ) -> HistoryEventDetailsModel {
        let isTestnet = network == .testnet
        let title = signedAmountFormatter.format(
            amount: BigUInt(integerLiteral: UInt64(abs(action.amount))),
            fractionDigits: TonInfo.fractionDigits,
            accessory: .currency(Currency.TON),
            isNegative: true,
            style: .exactValue
        )
        let dateString = TKLocales.EventDetails.stakedOn(date)

        var listItems = [HistoryEventDetailsModel.ListItem]()
        if let poolName = action.pool.name {
            listItems.append(.recipient(value: poolName, copyValue: poolName))
        }
        listItems.append(
            .recipientAddress(
                value: action.pool.address.toString(testOnly: isTestnet, bounceable: !action.pool.isWallet),
                copyValue: action.pool.address.toString(testOnly: isTestnet, bounceable: !action.pool.isWallet)
            )
        )
        listItems.append(.extra(value: extra, isRefund: isRefund, converted: extraConverted))

        return HistoryEventDetailsModel(
            title: title,
            aboveTitle: nil,
            date: dateString,
            fiatPrice: nil,
            warningText: status.rawValue,
            isScam: activityEvent.isScam,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    func mapSmartContractExec(
        activityEvent: AccountEvent,
        smartContractExec: AccountEventAction.SmartContractExec,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?,
        network: Network
    ) -> HistoryEventDetailsModel {
        let isTestnet = network == .testnet
        let fiatPrice = convertTonToFiatString(amount: BigUInt(smartContractExec.tonAttached))

        let title = signedAmountFormatter.format(
            amount: BigUInt(integerLiteral: UInt64(abs(smartContractExec.tonAttached))),
            fractionDigits: TonInfo.fractionDigits,
            accessory: .currency(Currency.TON),
            isNegative: true,
            style: .exactValue
        )
        let dateString = TKLocales.EventDetails.calledContractOn(date)

        var listItems = [HistoryEventDetailsModel.ListItem]()
        listItems.append(
            .other(
                title: "Address",
                value: smartContractExec.contract.address.toString(testOnly: isTestnet),
                copyValue: smartContractExec.contract.address.toString(testOnly: isTestnet)
            )
        )
        listItems.append(
            .operation(smartContractExec.operation)
        )
        listItems.append(.extra(value: extra, isRefund: isRefund, converted: extraConverted))
        if let payload = smartContractExec.payload {
            listItems.append(
                .other(
                    title: TKLocales.EventDetails.payload,
                    value: payload,
                    copyValue: payload
                )
            )
        }

        return HistoryEventDetailsModel(
            title: title,
            date: dateString,
            fiatPrice: fiatPrice,
            warningText: status.rawValue,
            isScam: activityEvent.isScam,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    func mapWithdrawStakeRequest(
        activityEvent: AccountEvent,
        action: AccountEventAction.WithdrawStakeRequest,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?,
        network: Network
    ) -> HistoryEventDetailsModel {
        let isTestnet = network == .testnet
        let title = TKLocales.EventDetails.unstakeRequest
        let dateString = "\(date)"

        var listItems = [HistoryEventDetailsModel.ListItem]()
        if let poolName = action.pool.name {
            listItems.append(.sender(value: poolName, copyValue: poolName))
        }
        listItems.append(
            .senderAddress(
                value: action.pool.address.toString(
                    testOnly: isTestnet,
                    bounceable: !action.pool.isWallet
                ),
                copyValue: action.pool.address.toString(
                    testOnly: isTestnet,
                    bounceable: !action.pool.isWallet
                )
            )
        )
        if let amount = action.amount {
            let formattedAmount = signedAmountFormatter.format(
                amount: BigUInt(integerLiteral: UInt64(abs(amount))),
                fractionDigits: TonInfo.fractionDigits,
                accessory: .currency(Currency.TON)
            )
            listItems.append(.other(
                title: TKLocales.EventDetails.unstakeAmount,
                value: formattedAmount,
                copyValue: formattedAmount
            ))
        }
        listItems.append(.extra(value: extra, isRefund: isRefund, converted: extraConverted))

        return HistoryEventDetailsModel(
            title: title,
            aboveTitle: nil,
            date: dateString,
            fiatPrice: nil,
            warningText: status.rawValue,
            isScam: activityEvent.isScam,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    func mapWithdrawStake(
        activityEvent: AccountEvent,
        action: AccountEventAction.WithdrawStake,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?,
        network: Network
    ) -> HistoryEventDetailsModel {
        let isTestnet = network == .testnet
        let amount = BigUInt(integerLiteral: UInt64(abs(action.amount)))
        let title = signedAmountFormatter.format(
            amount: amount,
            fractionDigits: TonInfo.fractionDigits,
            accessory: .currency(Currency.TON),
            style: .exactValue
        )
        let fiatPrice = convertTonToFiatString(amount: amount)

        let dateString = TKLocales.EventDetails.unstakeOn(date)

        var listItems = [HistoryEventDetailsModel.ListItem]()
        if let poolName = action.pool.name {
            listItems.append(.sender(value: poolName, copyValue: poolName))
        }
        listItems.append(
            .senderAddress(
                value: action.pool.address.toString(
                    testOnly: isTestnet,
                    bounceable: !action.pool.isWallet
                ),
                copyValue: action.pool.address.toString(
                    testOnly: isTestnet,
                    bounceable: !action.pool.isWallet
                )
            )
        )
        listItems.append(.extra(value: extra, isRefund: isRefund, converted: extraConverted))

        return HistoryEventDetailsModel(
            title: title,
            date: dateString,
            fiatPrice: fiatPrice,
            warningText: status.rawValue,
            isScam: activityEvent.isScam,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    func mapContractDeploy(
        activityEvent: AccountEvent,
        action: AccountEventAction.ContractDeploy,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        status: AccountEventStatus,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?
    ) -> HistoryEventDetailsModel {
        HistoryEventDetailsModel(
            title: TKLocales.EventDetails.walletInitialized,
            date: date,
            fiatPrice: nil,
            warningText: status.rawValue,
            isScam: activityEvent.isScam,
            listItems: [.extra(value: extra, isRefund: isRefund, converted: extraConverted)],
            detailsButton: detailsButton
        )
    }

    func mapUnknownAction(
        simplePreview: AccountEventAction.SimplePreview,
        date: String,
        extra: String,
        extraConverted: String?,
        isRefund: Bool,
        detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton?
    ) -> HistoryEventDetailsModel {
        let title = simplePreview.name
        let listItems: [HistoryEventDetailsModel.ListItem] = [
            .operation(simplePreview.name),
            .description(simplePreview.description),
            .extra(value: extra, isRefund: isRefund, converted: extraConverted),
        ]
        return HistoryEventDetailsModel(
            title: title,
            date: date,
            warningText: nil,
            isScam: false,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }

    private func warningText(for nft: NFT, status: AccountEventStatus) -> String? {
        if let status = status.rawValue {
            return status
        } else if nft.isUnverified {
            return TKLocales.NftDetails.unverifiedNft
        } else {
            return nil
        }
    }

    private func warningText(for jetton: JettonInfo, status: AccountEventStatus) -> String? {
        if let status = status.rawValue {
            return status
        } else if jetton.isUnverified {
            return TKLocales.Token.unverified
        } else {
            return nil
        }
    }

    private func warningTextForSwap(jettonIn: JettonInfo?, jettonOut: JettonInfo?, status: AccountEventStatus) -> String? {
        if let status = status.rawValue {
            return status
        } else if jettonIn?.isUnverified == true || jettonOut?.isUnverified == true {
            return TKLocales.Token.unverified
        } else {
            return nil
        }
    }

    private func createEncryptedCommentListItem(
        encryptedComment: EncryptedComment,
        eventId: AccountEvent.EventID,
        senderAddress: Address,
        decryptedCommentProvider: (_ eventId: String, _ payload: EncryptedCommentPayload) -> String?
    ) -> HistoryEventDetailsModel.ListItem {
        let payload = EncryptedCommentPayload(
            encryptedComment: encryptedComment,
            senderAddress: senderAddress
        )
        if let decrypted = decryptedCommentProvider(eventId, payload) {
            return .encryptedComment(.decrypted(decrypted))
        } else {
            return .encryptedComment(.encrypted(payload: payload))
        }
    }

    private func convertTonToFiatString(amount: BigUInt) -> String? {
        let currency = currencyStore.getState()
        guard let tonRate = tonRatesStore.getState().tonRates.first(where: { $0.currency == currency }) else {
            return nil
        }

        let fiat = rateConverter.convert(
            amount: amount,
            amountFractionLength: TonInfo.fractionDigits,
            rate: tonRate
        )

        return amountFormatter.format(
            amount: fiat.amount,
            fractionDigits: fiat.fractionLength,
            accessory: .currency(currency)
        )
    }

    private func jettonFiatString(amount: BigUInt, jettonInfo: JettonInfo) -> String? {
        return nil
    }
}
