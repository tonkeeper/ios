import BigInt
import Foundation
import KeeperCore
import TronSwift

enum SendV3Item {
    case ton(TonSendData.Item)
    case tron(TronSendData.Item)

    func setAmount(amount: BigUInt) -> SendV3Item {
        switch self {
        case let .ton(item):
            switch item {
            case let .token(token, _):
                return .ton(.token(token, amount: amount))
            case .nft:
                return self
            }
        case let .tron(item):
            return .tron(item.settingAmount(amount))
        }
    }

    var fractionalDigits: Int {
        switch self {
        case let .ton(item):
            switch item {
            case let .token(token, _):
                return token.fractionDigits
            default:
                return 0
            }
        case let .tron(item):
            return item.token.fractionDigits
        }
    }

    var amount: BigUInt {
        switch self {
        case let .ton(item):
            switch item {
            case let .token(_, amount):
                return amount
            default:
                return 0
            }
        case let .tron(item):
            return item.amount
        }
    }

    var isSupportComment: Bool {
        switch self {
        case .ton:
            return true
        case .tron:
            return false
        }
    }
}

enum LegacySendData {
    case ton(TonSendData)
    case tron(TronSendData)

    static func make(
        wallet: Wallet,
        recipient: LegacyRecipient?,
        item: SendV3Item,
        comment: String?,
        isMaxAmount: Bool,
        recipientDisplayAddress: String? = nil,
        estimatedDurationSeconds: Int? = nil
    ) -> LegacySendData? {
        guard let recipient else { return nil }
        switch (item, recipient) {
        case let (.ton(item), .ton(recipient)):
            return .ton(
                TonSendData(
                    wallet: wallet,
                    recipient: recipient,
                    item: item,
                    comment: comment,
                    isMaxAmount: isMaxAmount,
                    recipientDisplayAddress: recipientDisplayAddress,
                    estimatedDurationSeconds: estimatedDurationSeconds
                )
            )
        case let (.tron(item), .tron(recipient)):
            return .tron(
                TronSendData(
                    wallet: wallet,
                    recipient: recipient,
                    item: item,
                    recipientDisplayAddress: recipientDisplayAddress,
                    estimatedDurationSeconds: estimatedDurationSeconds
                )
            )
        default:
            return nil
        }
    }
}

enum SendInput {
    case direct(item: SendV3Item)
    case withdraw(sourceAsset: OnRampLayoutToken, exchangeTo: OnRampLayoutCryptoMethod)
}

struct MultichainSendInput {
    let item: MultichainSendItem

    /// Skipping the form must not skip what the form validates. An amount the balance cannot cover,
    /// or a recipient the form would reject, belongs on the prefilled form that says so — not on a
    /// confirmation screen where neither check runs.
    func isReadyForConfirmation(recipient: MultichainRecipient?, wallet: Wallet) -> Bool {
        guard item.amount > 0,
              item.amount <= item.asset.balance,
              let recipient
        else {
            return false
        }

        let recipientState = MultichainSendRecipientState.resolved(
            input: recipient.address,
            recipient: recipient,
            isMemoRequired: false
        )
        return recipientState.validation(
            expectedChain: item.asset.asset.chain,
            forbiddenSelfSendAddress: item.forbiddenSelfSendAddress(wallet: wallet)
        ) == .valid
    }
}

struct MultichainSendItem {
    let asset: MultichainAsset
    let amount: BigUInt

    func setAmount(_ amount: BigUInt) -> MultichainSendItem {
        MultichainSendItem(
            asset: asset,
            amount: amount
        )
    }

    func setAsset(_ asset: MultichainAsset) -> MultichainSendItem {
        MultichainSendItem(
            asset: asset,
            amount: 0
        )
    }

    var fractionalDigits: Int {
        asset.asset.decimals
    }

    var isSupportComment: Bool {
        asset.asset.chain == .ton
    }

    /// TRON rejects a native TRX transfer to the sender's own address, so it is not a recipient the
    /// send flow may accept — whether it was typed into the form or arrived pinned by a deeplink.
    func forbiddenSelfSendAddress(wallet: Wallet) -> String? {
        guard asset.isNative, asset.asset.chain == .tron else {
            return nil
        }
        return wallet.multichainWalletState?.address(for: .tron) ?? wallet.tron?.address.base58
    }
}
