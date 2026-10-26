import BigInt

/// One way to pay the fee of an EVM transfer. What the fee is denominated in says who pays the
/// chain: the chain's coin is paid by the wallet; battery charges and a token of the chain are paid
/// by the relayer, which then broadcasts the transfer.
struct EVMGaslessFeeOption: Equatable {
    enum Payer: Equatable {
        case battery(charges: Int)
        case token(MultichainAssetDetails, fee: BigUInt)
        case native(MultichainAssetDetails, fee: BigUInt)
    }

    var payer: Payer
    /// The relayer's id of the asset the fee is paid in; nil for the chain's coin, which the relayer
    /// does not price.
    var relayerAssetId: String?
    /// False when the relayer or the amount being sent rules the method out, whatever the balance says.
    var isAvailable = true
    /// The wallet does not cover the fee — plus the amount, when both come out of the sent asset.
    var isInsufficient = false

    var canPay: Bool {
        isAvailable && !isInsufficient
    }

    var isBattery: Bool {
        guard case .battery = payer else {
            return false
        }
        return true
    }

    var isNative: Bool {
        guard case .native = payer else {
            return false
        }
        return true
    }

    var isRelayed: Bool {
        !isNative
    }

    var fee: BigUInt {
        switch payer {
        case let .battery(charges):
            BigUInt(max(charges, 0))
        case let .token(_, fee), let .native(_, fee):
            fee
        }
    }

    var extraType: TransactionConfirmationModel.ExtraType {
        switch payer {
        case .battery:
            .battery
        case let .token(asset, _), let .native(asset, _):
            .multichain(token: asset)
        }
    }

    var extraValue: TransactionConfirmationModel.ExtraValue {
        switch payer {
        case let .battery(charges):
            .battery(charges: charges, excess: nil)
        case let .token(asset, fee), let .native(asset, fee):
            .multichain(token: asset, amount: fee)
        }
    }

    /// Whether `extraType` names this method. An asset is told by its id alone: the row a pick is
    /// made from and each quote it is resolved in describe the asset from lookups of their own,
    /// which can describe it otherwise or miss the wallet's entry and keep the relayer's.
    func isNamed(by extraType: TransactionConfirmationModel.ExtraType?) -> Bool {
        switch (self.extraType, extraType) {
        case (.battery, .battery?):
            true
        case let (.multichain(asset), .multichain(named)?):
            AssetIdComponents.isSameAsset(asset.assetId, named.assetId)
        default:
            false
        }
    }

    /// Rendered as insufficient whenever the method cannot pay: the screen has no other word for
    /// a method the relayer ruled out.
    var extraOption: TransactionConfirmationModel.ExtraOption {
        TransactionConfirmationModel.ExtraOption(
            type: extraType,
            value: extraValue,
            isInsufficient: !canPay
        )
    }

    /// The same method at the price the relayer's emulation named.
    func priced(_ fee: BigUInt) -> EVMGaslessFeeOption {
        var option = self
        switch payer {
        case .battery:
            option.payer = .battery(charges: Int(clamping: fee))
        case let .token(asset, _):
            option.payer = .token(asset, fee: fee)
        case let .native(asset, _):
            option.payer = .native(asset, fee: fee)
        }
        return option
    }
}

/// How the fee methods of an EVM transfer are listed and which one holds the selection.
enum EVMGaslessFeeSelection {
    /// Battery, then the chain's coin, then a fee in the asset being sent, then a fee in any other
    /// asset; the methods that cannot pay keep that order below the ones that can.
    static func prioritize(
        _ options: [EVMGaslessFeeOption],
        sentAssetId: String
    ) -> [EVMGaslessFeeOption] {
        let ranked = options.enumerated().sorted { lhs, rhs in
            let lhsRank = rank(lhs.element, sentAssetId: sentAssetId)
            let rhsRank = rank(rhs.element, sentAssetId: sentAssetId)
            return lhsRank == rhsRank ? lhs.offset < rhs.offset : lhsRank < rhsRank
        }
        return payableFirst(ranked.map(\.element))
    }

    static func payableFirst(_ options: [EVMGaslessFeeOption]) -> [EVMGaslessFeeOption] {
        options.filter(\.canPay) + options.filter { !$0.canPay }
    }

    /// The pick while it can pay. A pick that cannot hands the selection to the head of the list,
    /// then to the chain's coin — the method that always exists — then to anything that can pay;
    /// when nothing can, it stays where it is so the screen shows what is short.
    static func resolve(
        _ options: [EVMGaslessFeeOption],
        picked: TransactionConfirmationModel.ExtraType?
    ) -> EVMGaslessFeeOption? {
        guard let head = options.first else {
            return nil
        }
        // An unavailable method cannot hold the selection: it goes back to the head of the list.
        let pick = options.first { $0.isNamed(by: picked) && $0.isAvailable }
        if let pick, pick.canPay {
            return pick
        }
        let candidate = pick ?? head
        if candidate.canPay {
            return candidate
        }
        return options.first { $0.isNative && $0.canPay }
            ?? options.first(where: \.canPay)
            ?? candidate
    }

    /// `option` with the relayer's answer applied in place of its estimate; the list keeps its order.
    static func replacing(
        _ option: EVMGaslessFeeOption,
        in options: [EVMGaslessFeeOption]
    ) -> [EVMGaslessFeeOption] {
        options.map { $0.isNamed(by: option.extraType) ? option : $0 }
    }

    /// `option` ruled out by the relayer after all: it drops below the methods that can pay.
    static func rulingOut(
        _ option: EVMGaslessFeeOption,
        in options: [EVMGaslessFeeOption]
    ) -> [EVMGaslessFeeOption] {
        var unavailable = option
        unavailable.isAvailable = false
        return payableFirst(replacing(unavailable, in: options))
    }

    private static func rank(_ option: EVMGaslessFeeOption, sentAssetId: String) -> Int {
        switch option.payer {
        case .battery:
            0
        case .native:
            1
        case let .token(asset, _):
            AssetIdComponents.isSameAsset(asset.assetId, sentAssetId) ? 2 : 3
        }
    }
}
