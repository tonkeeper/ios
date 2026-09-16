import BigInt
import TonSwift

enum TonJettonSwapTransferFactory {
    static func makeTransfer(
        sourceAsset: MultichainAsset,
        deposit: TonJettonSwapDeposit,
        jettons: [JettonBalance],
        transferAmount: BigUInt
    ) -> Transfer? {
        guard let jettonItem = jettonItem(sourceAsset: sourceAsset, jettons: jettons),
              let recipientAddress = try? AnyAddress(rawAddress: deposit.recipient).address
        else {
            return nil
        }
        return .jetton(
            jettonItem,
            transferAmount: transferAmount,
            amount: deposit.amount,
            recipient: TonRecipient(
                recipientAddress: .raw(recipientAddress),
                isMemoRequired: false,
                isScam: false
            ),
            comment: nil
        )
    }

    static func jettonItem(
        sourceAsset: MultichainAsset,
        jettons: [JettonBalance]
    ) -> JettonItem? {
        guard let masterAddress = jettonMasterAddress(sourceAsset: sourceAsset),
              let jettonItem = jettons.first(where: { $0.item.jettonInfo.address == masterAddress })?.item,
              jettonItem.walletAddress != nil
        else {
            return nil
        }
        return jettonItem
    }

    static func jettonMasterAddress(sourceAsset: MultichainAsset) -> Address? {
        guard case let .asset(chain, _, type, address) = AssetIdComponents(assetId: sourceAsset.asset.assetId),
              chain.lowercased() == "ton",
              type.lowercased() == "jetton"
        else {
            return nil
        }
        return try? Address.parse(address)
    }

    static func requiredTransferAmount(
        minimum: BigUInt,
        emulationAmount: TransferEmulationResult.Extra.Amount
    ) -> BigUInt {
        switch emulationAmount {
        case let .fee(fee):
            return minimum + fee
        case .refund:
            return minimum
        }
    }
}
