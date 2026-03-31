import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

enum HistoryEventDetailsEvent {
    case ton(AccountEventDetailsEvent)
    case tron(TronTransaction)
}

@MainActor
protocol HistoryEventDetailsModuleOutput: AnyObject {
    var didTapTransactionDetails: ((URL, String) -> Void)? { get set }
    var didSelectEncryptedComment: ((_ wallet: Wallet, _ payload: EncryptedCommentPayload, _ eventId: String) -> Void)? { get set }
    var didFinish: (() -> Void)? { get set }
}

@MainActor
protocol HistoryEventDetailsViewModel: AnyObject {
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }
    var didUpdateHeaderItem: ((TKPullCardHeaderItem) -> Void)? { get set }

    func viewDidLoad()
}

@MainActor
final class HistoryEventDetailsViewModelImplementation: HistoryEventDetailsViewModel, HistoryEventDetailsModuleOutput {
    // MARK: - HistoryEventDetailsModuleOutput

    var didTapTransactionDetails: ((URL, String) -> Void)?
    var didSelectEncryptedComment: ((Wallet, EncryptedCommentPayload, String) -> Void)?
    var didFinish: (() -> Void)?

    // MARK: - HistoryEventDetailsViewModel

    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?
    var didUpdateHeaderItem: ((TKPullCardHeaderItem) -> Void)?

    func viewDidLoad() {
        setupContent()

        decryptedCommentStore.addObserver(self) { observer, event in
            switch event {
            case let .didDecryptComment(eventId, wallet):
                guard case let .ton(accountEvent) = observer.event,
                      accountEvent.accountEvent.eventId == eventId,
                      wallet == observer.wallet
                else {
                    return
                }
                DispatchQueue.main.async {
                    observer.setupContent()
                }
            }
        }
    }

    // MARK: - Dependencies

    private let wallet: Wallet
    private let event: HistoryEventDetailsEvent
    private let historyEventDetailsMapper: HistoryEventDetailsMapper
    private let historyEventDetailsTronMapper: HistoryEventDetailsTronMapper
    private let decryptedCommentStore: DecryptedCommentStore
    private let transactionsManagementStore: TransactionsManagement.Store

    // MARK: - Init

    init(
        wallet: Wallet,
        event: HistoryEventDetailsEvent,
        historyEventDetailsMapper: HistoryEventDetailsMapper,
        historyEventDetailsTronMapper: HistoryEventDetailsTronMapper,
        decryptedCommentStore: DecryptedCommentStore,
        transactionsManagementStore: TransactionsManagement.Store
    ) {
        self.wallet = wallet
        self.event = event
        self.historyEventDetailsMapper = historyEventDetailsMapper
        self.historyEventDetailsTronMapper = historyEventDetailsTronMapper
        self.decryptedCommentStore = decryptedCommentStore
        self.transactionsManagementStore = transactionsManagementStore
    }
}

private extension HistoryEventDetailsViewModelImplementation {
    func setupContent() {
        let model: HistoryEventDetailsModel = {
            switch event {
            case let .ton(event):
                historyEventDetailsMapper.mapEvent(event: event) { eventId, payload in
                    decryptedCommentStore.getDecryptedComment(wallet: wallet, payload: payload, eventId: eventId)
                }
            case let .tron(event):
                historyEventDetailsTronMapper.mapEvent(event: event)
            }
        }()
        self.configure(model: model)
    }

    func configure(model: HistoryEventDetailsModel) {
        var items = [TKPopUp.Item]()

        if let spamItem = configureSpamItem(model: model) {
            items.append(spamItem)
        }
        if let headerImage = configureHeaderImage(model: model) {
            items.append(headerImage)
        }

        let labelsGroup: TKPopUp.Component.GroupComponent = {
            var items = [TKPopUp.Item]()

            items.append(contentsOf: configureNFTItems(model: model))

            if let aboveTitle = model.aboveTitle {
                items.append(
                    TKPopUp.Component.LabelComponent(
                        text: aboveTitle.withTextStyle(.h2, color: .Text.tertiary, alignment: .center),
                        numberOfLines: 1,
                        bottomSpace: 4
                    )
                )
            }
            if let title = model.title {
                items.append(
                    TKPopUp.Component.LabelComponent(
                        text: title.withTextStyle(.h2, color: .Text.primary, alignment: .center),
                        numberOfLines: 2,
                        bottomSpace: 4
                    )
                )
            }
            if let fiatPrice = model.fiatPrice {
                items.append(
                    TKPopUp.Component.LabelComponent(
                        text: fiatPrice.withTextStyle(.body1, color: .Text.secondary, alignment: .center),
                        numberOfLines: 1,
                        bottomSpace: 4
                    )
                )
            }
            if let date = model.date {
                items.append(
                    TKPopUp.Component.LabelComponent(
                        text: date.withTextStyle(.body1, color: .Text.secondary, alignment: .center),
                        numberOfLines: 1,
                        bottomSpace: 0
                    )
                )
            }
            if let warningText = model.warningText {
                items.append(
                    TKPopUp.Component.LabelComponent(
                        text: warningText.withTextStyle(.body1, color: .Accent.orange, alignment: .center),
                        numberOfLines: 1,
                        bottomSpace: 0
                    )
                )
            }
            return TKPopUp.Component.GroupComponent(
                padding: UIEdgeInsets(top: 0, left: 32, bottom: 32, right: 32),
                items: items
            )
        }()
        items.append(labelsGroup)
        if let listItem = configureListItems(model: model) {
            items.append(
                TKPopUp.Component.GroupComponent(
                    padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16),
                    items: [listItem]
                )
            )
        }

        let isManagementButtonVisible: Bool = {
            guard let management = model.management else { return false }
            return management.state == nil && management.isManagementAvailable
        }()

        if isManagementButtonVisible,
           wallet.isReportSpamAvailable,
           !model.isScam
        {
            items.append(TKPopUp.Component.GroupComponent(
                padding: UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0),
                items: [configureTransactionManagementBlock()]
            ))
        } else if let transactionButtonItem = configureTransactionButton(model: model) {
            items.append(TKPopUp.Component.GroupComponent(
                padding: UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0),
                items: [transactionButtonItem]
            ))
        }

        let configuration = TKPopUp.Configuration(items: items)

        didUpdateConfiguration?(configuration)

        configureHeader(model: model)
    }

    func configureHeader(model: HistoryEventDetailsModel) {
        let buttonModel = TKUIHeaderIconButton.Model(image: .TKUIKit.Icons.Size16.ellipses)
        let headerButton = TKPullCardHeaderItem.LeftButton(model: buttonModel, action: { [weak self] targetView in
            guard let self else {
                return
            }

            TKPopupMenuController.show(
                sourceView: targetView,
                position: .bottomLeft(inset: 8),
                width: 0,
                items: setupMenuItems(model: model),
                isSelectable: false,
                selectedIndex: nil
            )
        }, isEnabled: true)

        let headerItem = TKPullCardHeaderItem(
            title: .title(title: "", subtitle: nil),
            leftButton: headerButton
        )
        didUpdateHeaderItem?(headerItem)
    }

    func setupMenuItems(model: HistoryEventDetailsModel) -> [TKPopupMenuItem] {
        var menuItems = [TKPopupMenuItem]()
        if let management = model.management,
           management.isManagementAvailable,
           wallet.isReportSpamAvailable
        {
            let title: String = {
                switch management.state {
                case .normal:
                    TKLocales.EventDetails.reportSpam
                case .spam:
                    TKLocales.EventDetails.notSpam
                case .none:
                    model.isScam ? TKLocales.EventDetails.notSpam : TKLocales.EventDetails.reportSpam
                }
            }()

            let action: () -> Void = { [weak self] in
                switch management.state {
                case .normal:
                    self?.reportSpam()
                case .spam:
                    self?.notSpam()
                case .none:
                    model.isScam ? self?.notSpam() : self?.reportSpam()
                }
            }

            menuItems.append(
                TKPopupMenuItem(
                    title: title,
                    icon: .TKUIKit.Icons.Size16.block,
                    selectionHandler: action
                )
            )
        }

        if let detailsButton = model.detailsButton {
            let openInExplorerItem = TKPopupMenuItem(
                title: TKLocales.Actions.viewOn(detailsButton.browserTitle),
                icon: .TKUIKit.Icons.Size16.globe,
                selectionHandler: { [weak self] in
                    self?.didTapTransactionDetails?(detailsButton.url, detailsButton.browserTitle)
                }
            )
            menuItems.append(openInExplorerItem)
        }
        return menuItems
    }

    func configureSpamItem(model: HistoryEventDetailsModel) -> TKPopUp.Item? {
        guard model.isScam else { return nil }
        return HistoryEventDetailsSpamComponent(
            configuration: HistoryEventDetailsSpamView.Configuration(
                title: TKLocales.ActionTypes.spam.uppercased().withTextStyle(
                    .label2,
                    color: .Constant.white,
                    alignment: .center
                )
            ),
            bottomSpace: 12
        )
    }

    func configureHeaderImage(model: HistoryEventDetailsModel) -> TKPopUp.Item? {
        guard !model.isScam else { return nil }
        guard let headerImage = model.headerImage else { return nil }

        switch headerImage {
        case let .transfer(item):
            return item
        case let .swap(fromImage, toImage):
            return HistoryEventDetailsSwapHeaderComponent(
                configuration: HistoryEventDetailsSwapHeaderView.Configuration(
                    leftImageModel: TKImageView.Model(
                        image: fromImage.tkImage,
                        tintColor: .Icon.primary,
                        size: .size(CGSize(width: 76, height: 76)),
                        corners: .circle
                    ),
                    rightImageModel: TKImageView.Model(
                        image: toImage.tkImage,
                        tintColor: .Icon.primary,
                        size: .size(CGSize(width: 76, height: 76)),
                        corners: .circle
                    )
                ),
                bottomSpace: 20
            )
        }
    }

    func configureNFTItems(model: HistoryEventDetailsModel) -> [TKPopUp.Item] {
        guard !model.isScam else { return [] }
        guard let nftModel = model.nftModel else { return [] }
        guard let nftName = nftModel.name else { return [] }
        var items = [TKPopUp.Item]()
        items.append(TKPopUp.Component.LabelComponent(text: nftName.withTextStyle(.h2, color: .Text.primary, alignment: .center)))
        if let collectionName = nftModel.collectionName {
            items.append(
                HistoryEventDetailsNFTCollectionComponent(
                    configuration: HistoryEventDetailsNFTCollectionView.Configuration(
                        name: collectionName,
                        isVerified: nftModel.isVerified
                    ),
                    bottomSpace: 16
                )
            )
        }
        return items
    }

    private func configureListItems(model: HistoryEventDetailsModel) -> TKPopUp.Component.List? {
        guard !model.listItems.isEmpty else {
            return nil
        }

        let items = model.listItems.map { configureListItem($0) }
        return TKPopUp.Component.List(
            configuration: TKListContainerView.Configuration(
                items: items,
                copyToastConfiguration: .copied
            )
        )
    }

    private func configureListItem(_ modelListItem: HistoryEventDetailsModel.ListItem) -> TKListContainerItem {
        let item: TKListContainerItem
        switch modelListItem {
        case let .recipient(value, copyValue):
            item = TKListContainerItemView.Model(
                title: TKLocales.EventDetails.recipient,
                value: .value(
                    TKListContainerItemDefaultValueView.Model(
                        topValue: TKListContainerItemDefaultValueView.Model.Value(value: value)
                    )
                ),
                action: .copy(copyValue: copyValue)
            )
        case let .recipientAddress(value, copyValue):
            item = TKListContainerFullValueItemItem(
                title: TKLocales.EventDetails.recipientAddress,
                value: value,
                copyValue: copyValue
            )
        case let .sender(value, copyValue):
            item = TKListContainerItemView.Model(
                title: TKLocales.EventDetails.sender,
                value: .value(
                    TKListContainerItemDefaultValueView.Model(
                        topValue: TKListContainerItemDefaultValueView.Model.Value(value: value)
                    )
                ),
                action: .copy(copyValue: copyValue)
            )
        case let .senderAddress(value, copyValue):
            item = TKListContainerFullValueItemItem(
                title: TKLocales.EventDetails.senderAddress,
                value: value,
                copyValue: copyValue
            )
        case let .extra(value, isRefund, converted):
            item = TKListContainerItemView.Model(
                title: isRefund ? TKLocales.EventDetails.refund : TKLocales.EventDetails.fee,
                value: .value(
                    TKListContainerItemDefaultValueView.Model(
                        topValue: TKListContainerItemDefaultValueView.Model.Value(value: value),
                        bottomValue: TKListContainerItemDefaultValueView.Model.Value(value: converted)
                    )
                ),
                action: nil
            )
        case let .refund(value, converted):
            item = TKListContainerItemView.Model(
                title: "Refund",
                value: .value(
                    TKListContainerItemDefaultValueView.Model(
                        topValue: TKListContainerItemDefaultValueView.Model.Value(value: value),
                        bottomValue: TKListContainerItemDefaultValueView.Model.Value(value: converted)
                    )
                ),
                action: nil
            )
        case let .comment(string):
            item = TKListContainerItemView.Model(
                title: TKLocales.EventDetails.comment,
                value: .value(
                    TKListContainerItemDefaultValueView.Model(
                        topValue: TKListContainerItemDefaultValueView.Model.Value(value: string, numberOfLines: 0)
                    )
                ),
                action: .copy(copyValue: string)
            )
        case let .encryptedComment(encryptedComment):
            let value: HistoryEventDetailsListContainerItemEncryptedCommenValueView.Configuration = {
                switch encryptedComment {
                case let .decrypted(value):
                    .decrypted(text: value)
                case let .encrypted(payload):
                    .encrypted(text: payload.encryptedComment.cipherText)
                }
            }()

            let action: TKListContainerItemAction = {
                switch encryptedComment {
                case let .decrypted(value):
                    return .copy(copyValue: value)
                case let .encrypted(payload):
                    return .custom { [weak self, wallet, event] _ in
                        guard case let .ton(event) = event else { return }
                        self?.didSelectEncryptedComment?(wallet, payload, event.accountEvent.eventId)
                    }
                }
            }()

            item = TKListContainerItemView.Model(
                id: "encrypted_comment_item",
                title: TKLocales.EventDetails.comment,
                titleIcon: TKListContainerItemView.Model.Icon(
                    image: .TKUIKit.Icons.Size12.lock,
                    tintColor: .Accent.green
                ),
                value: .value(
                    value
                ),
                action: action
            )
        case let .description(string):
            item = TKListContainerItemView.Model(
                title: TKLocales.EventDetails.description,
                value: .value(
                    TKListContainerItemDefaultValueView.Model(
                        topValue: TKListContainerItemDefaultValueView.Model.Value(value: string, numberOfLines: 0)
                    )
                ),
                action: .copy(copyValue: string)
            )
        case let .operation(value):
            item = TKListContainerItemView.Model(
                title: TKLocales.EventDetails.operation,
                value: .value(
                    TKListContainerItemDefaultValueView.Model(
                        topValue: TKListContainerItemDefaultValueView.Model.Value(value: value, numberOfLines: 0)
                    )
                ),
                action: .copy(copyValue: value)
            )
        case let .other(title, value, copyValue):
            item = TKListContainerItemView.Model(
                title: title,
                value: .value(
                    TKListContainerItemDefaultValueView.Model(
                        topValue: TKListContainerItemDefaultValueView.Model.Value(value: value, numberOfLines: 0)
                    )
                ),
                action: .copy(copyValue: copyValue)
            )
        }
        return item
    }

    func configureTransactionButton(model: HistoryEventDetailsModel) -> HistoryEventDetailsTransactionButtonComponent? {
        guard let detailsButton = model.detailsButton else { return nil }
        return HistoryEventDetailsTransactionButtonComponent(
            configuration: HistoryEventDetailsTransactionButtonView.Configuration(
                title: detailsButton.buttonTitle,
                action: { [weak self] in
                    self?.didTapTransactionDetails?(detailsButton.url, detailsButton.browserTitle)
                },
                longPressAction: {
                    ToastPresenter.showToast(configuration: .copied)
                    UIPasteboard.general.string = detailsButton.hash
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            ),
            bottomSpace: 32
        )
    }

    func configureTransactionManagementBlock() -> HistoryEventDetailsSpamManagementComponent {
        return HistoryEventDetailsSpamManagementComponent(
            configuration: HistoryEventDetailsSpamManagementComponentView.Configuration(
                reportSpamTitle: TKLocales.EventDetails.reportSpam,
                reportSpamAction: { [weak self] in
                    self?.reportSpam()
                },
                notSpamTitle: TKLocales.EventDetails.notSpam,
                notSpamAction: { [weak self] in
                    self?.notSpam()
                }
            ),
            bottomSpace: 32
        )
    }

    func reportSpam() {
        guard case let .ton(event) = event else { return }
        Task { [weak self] in
            guard let self else { return }
            ToastPresenter.showToast(configuration: .loading)
            await transactionsManagementStore.markAsSpam(event.accountEvent.eventId)
            self.didFinish?()
            ToastPresenter.hideAll()
            ToastPresenter.showToast(
                configuration: ToastPresenter.Configuration(title: TKLocales.EventDetails.transactionMarkedAsSpam, dismissRule: .default)
            )
        }
    }

    func notSpam() {
        guard case let .ton(event) = event else { return }
        Task { [weak self] in
            guard let self else { return }
            await transactionsManagementStore.markAsNormal(event.accountEvent.eventId)
            setupContent()
        }
    }
}

private extension TokenImage {
    var tkImage: TKImage {
        switch self {
        case .ton:
            return .image(.TKUIKit.Icons.Size44.tonCurrency)
        case .usdt:
            return .image(.App.Currency.Size44.usdt)
        case let .url(url):
            return .urlImage(url)
        }
    }
}
