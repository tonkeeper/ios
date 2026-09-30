@preconcurrency import BigInt
import Foundation

public struct WalletMigrationPrepareResult: Sendable {
    public enum FeeMethod: Equatable, Sendable {
        case ton(amountNano: UInt64)
        case battery(charges: Int)

        public var isBattery: Bool {
            if case .battery = self {
                return true
            }
            return false
        }
    }

    public let from: String
    public let to: String
    public let walletVersion: String
    public let transactions: [WalletMigrationPreparedTransaction]
    public let batteryTransactions: [WalletMigrationPreparedTransaction]?
    public let availableFeeMethods: [FeeMethod]
    public let availableTonNano: UInt64?
    public let requiredTonNano: UInt64?

    public init(
        from: String,
        to: String,
        walletVersion: String,
        transactions: [WalletMigrationPreparedTransaction],
        batteryTransactions: [WalletMigrationPreparedTransaction]? = nil,
        availableFeeMethods: [FeeMethod] = [],
        availableTonNano: UInt64? = nil,
        requiredTonNano: UInt64? = nil
    ) {
        self.from = from
        self.to = to
        self.walletVersion = walletVersion
        self.transactions = transactions
        self.batteryTransactions = batteryTransactions
        self.availableFeeMethods = availableFeeMethods
        self.availableTonNano = availableTonNano
        self.requiredTonNano = requiredTonNano
    }

    public func transactionsForExecution(
        feeMethod: FeeMethod
    ) -> [WalletMigrationPreparedTransaction] {
        switch feeMethod {
        case .ton:
            return transactions
        case .battery:
            return batteryTransactions ?? []
        }
    }

    /// Falls back to the self-paid transactions where `transactionsForExecution` returns none:
    /// a preview must stay populated where sending has to refuse.
    public func transactionsForPresentation(
        feeMethod: FeeMethod?
    ) -> [WalletMigrationPreparedTransaction] {
        guard let feeMethod else { return transactions }
        let resolved = transactionsForExecution(feeMethod: feeMethod)
        return resolved.isEmpty ? transactions : resolved
    }

    public var hasTransactions: Bool {
        !transactions.isEmpty
    }

    public var hasExecutableTransactions: Bool {
        hasTransactions || batteryTransactions?.isEmpty == false
    }

    public var hasBatteryExecutionPath: Bool {
        batteryTransactions?.isEmpty == false
    }

    public var transactionsForDisplay: [WalletMigrationPreparedTransaction] {
        hasTransactions ? transactions : batteryTransactions ?? []
    }

    public var totalFees: UInt64 {
        transactions.reduce(into: UInt64.zero) { partial, transaction in
            partial += transaction.totalFees
        }
    }

    public var isSelfPaidTonInsufficient: Bool {
        requiredTonNano != nil
    }

    /// Mirror of `WalletMigrationTronPrepareResult.blockingTRXShortage`: the shortage only blocks
    /// the migration when no offered fee method is payable. A server-reported reserve wins; with
    /// the server silent, the self-paid quote exceeding the loaded balance is claimed instead, so
    /// a wallet that cannot fund its own plan never reaches sending without the deposit banner.
    public func blockingTONShortage(
        isFeeMethodPayable: (FeeMethod) -> Bool
    ) -> (required: UInt64, available: UInt64)? {
        guard let availableTonNano else { return nil }
        guard !availableFeeMethods.contains(where: isFeeMethodPayable) else { return nil }
        if let requiredTonNano {
            return (requiredTonNano, availableTonNano)
        }
        for case let .ton(amountNano) in availableFeeMethods where amountNano > availableTonNano {
            return (amountNano, availableTonNano)
        }
        return nil
    }

    public var preferredFeeMethod: FeeMethod? {
        WalletMigrationTonFeeOptionsResolver.preferred(methods: availableFeeMethods)
    }

    /// Battery charge quote — only sponsored legs, preferring burned `gas_spent`/`totalFees`
    /// over `event.extra`. Extra is UI-oriented net Gram change and must not fold a GRAM
    /// sweep into the charge count.
    public static func batteryChargeBasisNano(
        from transactions: [WalletMigrationPreparedTransaction]?
    ) -> UInt64? {
        guard let transactions, transactions.contains(where: \.sponsored) else {
            return nil
        }
        let sponsored = transactions.filter(\.sponsored)
        let fromGasSpent = sponsored.reduce(into: UInt64.zero) { $0 += $1.totalFees }
        if fromGasSpent > 0 {
            return fromGasSpent
        }
        let fromExtra = sponsored.reduce(into: UInt64.zero) { $0 += $1.networkFeeNano }
        return fromExtra > 0 ? fromExtra : nil
    }
}

public struct WalletMigrationTronPrepareResult {
    public enum FeeMethod: Equatable {
        case battery(charges: Int)
        case trx(amountSun: BigUInt)

        public var isBattery: Bool {
            if case .battery = self {
                return true
            }
            return false
        }
    }

    public let sourceAddress: String
    public let destinationAddress: String
    public let usdtAmount: BigUInt
    public let requiredTRXSun: BigUInt
    public let availableTRXSun: BigUInt
    public let usdtRequiredTRXSun: BigUInt
    public let nativeRequiredTRXSun: BigUInt
    public let energy: Int
    public let bandwidth: Int
    public let trxEnergy: Int
    public let trxBandwidth: Int
    /// The destination TRON account does not exist yet, so the TRX leg carries the account-creation
    /// burn already folded into `nativeRequiredTRXSun`.
    public let destinationRequiresActivation: Bool
    public let availableFeeMethods: [FeeMethod]

    public init(
        sourceAddress: String,
        destinationAddress: String,
        usdtAmount: BigUInt,
        requiredTRXSun: BigUInt,
        availableTRXSun: BigUInt,
        usdtRequiredTRXSun: BigUInt = 0,
        nativeRequiredTRXSun: BigUInt = 0,
        energy: Int,
        bandwidth: Int,
        trxEnergy: Int = 0,
        trxBandwidth: Int = 0,
        destinationRequiresActivation: Bool = false,
        availableFeeMethods: [FeeMethod]
    ) {
        self.sourceAddress = sourceAddress
        self.destinationAddress = destinationAddress
        self.usdtAmount = usdtAmount
        self.requiredTRXSun = requiredTRXSun
        self.availableTRXSun = availableTRXSun
        self.usdtRequiredTRXSun = usdtRequiredTRXSun
        self.nativeRequiredTRXSun = nativeRequiredTRXSun
        self.energy = energy
        self.bandwidth = bandwidth
        self.trxEnergy = trxEnergy
        self.trxBandwidth = trxBandwidth
        self.destinationRequiresActivation = destinationRequiresActivation
        self.availableFeeMethods = availableFeeMethods
    }

    public var hasUSDT: Bool {
        usdtAmount > 0
    }

    public var hasTRX: Bool {
        availableTRXSun > 0
    }

    public var hasAssets: Bool {
        hasUSDT || hasTRX
    }

    public var hasInsufficientTRX: Bool {
        hasTRX ? availableTRXSun <= requiredTRXSun : availableTRXSun < requiredTRXSun
    }

    /// A method only counts as a way out if the fee selection can actually settle on it: Battery is
    /// offered whenever the relay quotes charges, while affording those charges depends on the balance
    /// and on what the TON leg claims from the same budget. `isFeeMethodPayable` carries that verdict
    /// in, so this stays the single place that decides whether a shortage blocks the migration.
    public func blockingTRXShortage(
        isFeeMethodPayable: (FeeMethod) -> Bool
    ) -> (required: BigUInt, available: BigUInt)? {
        guard hasInsufficientTRX else { return nil }
        let payableMethods = availableFeeMethods.filter(isFeeMethodPayable)
        if hasUSDT {
            guard !payableMethods.contains(where: \.isBattery) else { return nil }
        } else {
            // TRX is the whole leg here: Battery sponsors resources but not the destination-activation
            // burn, so the shortage only blocks when no offered method leaves anything to transfer.
            guard payableMethods.allSatisfy({ trxTransferAmount(for: $0) == 0 }) else { return nil }
        }
        return (requiredTRXSun, availableTRXSun)
    }

    public var preferredFeeMethod: FeeMethod? {
        availableFeeMethods.first { method in
            if case .trx = method {
                return !hasInsufficientTRX
            }
            return true
        } ?? availableFeeMethods.first
    }

    public var trxAmount: BigUInt {
        preferredFeeMethod.map { trxTransferAmount(for: $0) } ?? 0
    }

    public func reservedTRX(for feeMethod: FeeMethod) -> BigUInt {
        switch feeMethod {
        case .battery:
            return hasUSDT || destinationRequiresActivation ? nativeRequiredTRXSun : 0
        case .trx:
            return nativeRequiredTRXSun + (hasUSDT ? usdtRequiredTRXSun : 0)
        }
    }

    public func trxTransferAmount(for feeMethod: FeeMethod) -> BigUInt {
        let reserved = reservedTRX(for: feeMethod)
        guard availableTRXSun > reserved else { return 0 }
        return availableTRXSun - reserved
    }

    /// After a Battery-sponsored USDT send the destination may become activated and free
    /// bandwidth may cover the native transfer, so a prepare-time `trxTransferAmount` of 0
    /// must not permanently skip the leftover TRX sweep.
    public func shouldAttemptTrxSweep(feeMethod: FeeMethod) -> Bool {
        trxTransferAmount(for: feeMethod) > 0 || (hasUSDT && hasTRX)
    }

    /// Battery never reports a TRX shortage: either the remainder covers the self-paid
    /// native burn, or the TRX leg is skipped as non-transferable dust while the relay
    /// still executes the USDT leg.
    public func hasInsufficientTRX(for feeMethod: FeeMethod) -> Bool {
        guard case let .trx(amountSun) = feeMethod else { return false }
        let required = max(reservedTRX(for: feeMethod), amountSun)
        guard required > 0 else { return false }
        return hasTRX ? availableTRXSun <= required : availableTRXSun < required
    }

    public func displayedTRXAmount(for feeMethod: FeeMethod) -> BigUInt {
        let transferAmount = trxTransferAmount(for: feeMethod)
        if transferAmount > 0 {
            return transferAmount
        }
        // Confirm UI still lists TRX when a post-USDT live sweep will be attempted.
        return shouldAttemptTrxSweep(feeMethod: feeMethod) ? availableTRXSun : 0
    }
}

public struct WalletMigrationPreparedTransaction: Sendable {
    public let seqno: Int
    public let boc: String
    public let stateInit: String?
    public let messages: [WalletMigrationOutMessage]
    public let event: AccountEvent
    public let totalFees: UInt64
    public let totalEquivalent: Double?
    public let sponsored: Bool

    public init(
        seqno: Int,
        boc: String,
        stateInit: String? = nil,
        messages: [WalletMigrationOutMessage] = [],
        event: AccountEvent,
        totalFees: UInt64 = 0,
        totalEquivalent: Double?,
        sponsored: Bool = false
    ) {
        self.seqno = seqno
        self.boc = boc
        self.stateInit = stateInit
        self.messages = messages
        self.event = event
        self.totalFees = totalFees
        self.totalEquivalent = totalEquivalent
        self.sponsored = sponsored
    }

    public var networkFeeNano: UInt64 {
        switch event.extra {
        case let .Fee(fee):
            return fee
        case .Refund:
            return 0
        }
    }
}

public struct WalletMigrationOutMessage: Sendable {
    public let boc: String
    public let mode: Int

    public init(boc: String, mode: Int) {
        self.boc = boc
        self.mode = mode
    }
}

public struct WalletMigrationWalletValue: Sendable {
    public let account: String
    public let balance: Int64
    public let jettonsCount: Int
    public let nftCount: Int
    public let usdtAmount: BigUInt
    public let trxAmount: BigUInt
    public let fiatBalance: Decimal

    public init(
        account: String,
        balance: Int64,
        jettonsCount: Int,
        nftCount: Int,
        usdtAmount: BigUInt = 0,
        trxAmount: BigUInt = 0,
        fiatBalance: Decimal = 0
    ) {
        self.account = account
        self.balance = balance
        self.jettonsCount = jettonsCount
        self.nftCount = nftCount
        self.usdtAmount = usdtAmount
        self.trxAmount = trxAmount
        self.fiatBalance = fiatBalance
    }

    public var hasMigratableAssets: Bool {
        balance > 0 || jettonsCount > 0 || nftCount > 0 || usdtAmount > 0 || trxAmount > 0
    }
}
