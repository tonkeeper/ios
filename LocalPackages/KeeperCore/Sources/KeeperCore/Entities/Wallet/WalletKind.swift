import Foundation
import TonSwift

@frozen public enum WalletKind: Codable, Equatable, Hashable {
    case Regular(TonSwift.PublicKey, WalletContractVersion)
    case Lockup(TonSwift.PublicKey, LockupConfig)
    case Watchonly(ResolvableAddress, WalletContractVersion? = nil)
    case Signer(TonSwift.PublicKey, WalletContractVersion)
    case SignerDevice(TonSwift.PublicKey, WalletContractVersion)
    case Keystone(TonSwift.PublicKey, String?, String?, WalletContractVersion)
    case Ledger(TonSwift.PublicKey, WalletContractVersion, Wallet.LedgerDevice)

    public static func == (lhs: WalletKind, rhs: WalletKind) -> Bool {
        switch (lhs, rhs) {
        case let (.Regular(lpk, lv), .Regular(rpk, rv)):
            return lpk == rpk && lv == rv
        case let (.Lockup(lpk, lc), .Lockup(rpk, rc)):
            return lpk == rpk && lc == rc
        case let (.Watchonly(laddress, lv), .Watchonly(raddress, rv)):
            return laddress == raddress && lv == rv
        case let (.Signer(lpk, lv), .Signer(rpk, rv)):
            return lpk == rpk && lv == rv
        case let (.SignerDevice(lpk, lv), .SignerDevice(rpk, rv)):
            return lpk == rpk && lv == rv
        case let (.Ledger(lpk, lv, lledger), .Ledger(rpk, rv, rledger)):
            return lpk == rpk && lv == rv && lledger == rledger
        default: return false
        }
    }
}

extension TonSwift.PublicKey: @retroactive Equatable, @retroactive Hashable {
    public static func == (lhs: TonSwift.PublicKey, rhs: TonSwift.PublicKey) -> Bool {
        lhs.data == rhs.data
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}

extension WalletKind: CellCodable {
    private enum Tag: UInt64 {
        case regular = 0
        case lockup = 1
        case watchonly = 2
        case signer = 3
        case signerDevice = 4
        case ledger = 5
        case keystone = 6
        case watchonlyWithContractVersion = 7

        static let bitsCount = 5
    }

    public func storeTo(builder: Builder) throws {
        switch self {
        case let .Regular(publicKey, contractVersion):
            try builder.store(uint: Tag.regular.rawValue, bits: Tag.bitsCount)
            try publicKey.storeTo(builder: builder)
            try contractVersion.storeTo(builder: builder)
        case let .Lockup(publicKey, lockupConfig):
            try builder.store(uint: Tag.lockup.rawValue, bits: Tag.bitsCount)
            try publicKey.storeTo(builder: builder)
            try lockupConfig.storeTo(builder: builder)
        case let .Watchonly(resolvableAddress, contractVersion):
            if let contractVersion {
                try builder.store(uint: Tag.watchonlyWithContractVersion.rawValue, bits: Tag.bitsCount)
                try resolvableAddress.storeTo(builder: builder)
                try contractVersion.storeTo(builder: builder)
            } else {
                try builder.store(uint: Tag.watchonly.rawValue, bits: Tag.bitsCount)
                try resolvableAddress.storeTo(builder: builder)
            }
        case let .Signer(publicKey, contractVersion):
            try builder.store(uint: Tag.signer.rawValue, bits: Tag.bitsCount)
            try publicKey.storeTo(builder: builder)
            try contractVersion.storeTo(builder: builder)
        case let .SignerDevice(publicKey, contractVersion):
            try builder.store(uint: Tag.signerDevice.rawValue, bits: Tag.bitsCount)
            try publicKey.storeTo(builder: builder)
            try contractVersion.storeTo(builder: builder)
        case let .Ledger(publicKey, contractVersion, device):
            try builder.store(uint: Tag.ledger.rawValue, bits: Tag.bitsCount)
            try publicKey.storeTo(builder: builder)
            try contractVersion.storeTo(builder: builder)
            try device.storeTo(builder: builder)
        case let .Keystone(publicKey, xfp, path, contractVersion):
            try builder.store(uint: Tag.keystone.rawValue, bits: Tag.bitsCount)
            try publicKey.storeTo(builder: builder)
            if let xfp = xfp {
                let xfpNum: UInt64 = UInt64(xfp)!
                try builder.store(bit: true)
                try xfpNum.storeTo(builder: builder)
            } else {
                try builder.store(bit: false)
            }
            try contractVersion.storeTo(builder: builder)
            if let path = path {
                try builder.store(bit: true)
                try builder.store(slice: Builder().writeSnakeString(path).endCell().beginParse())
            } else {
                try builder.store(bit: false)
            }
        }
    }

    public static func loadFrom(slice: Slice) throws -> WalletKind {
        return try slice.tryLoad { s in
            switch try Tag(rawValue: s.loadUint(bits: Tag.bitsCount)) {
            case .regular:
                let publicKey: TonSwift.PublicKey = try s.loadType()
                let contractVersion: WalletContractVersion = try s.loadType()
                return .Regular(publicKey, contractVersion)
            case .lockup:
                let publicKey: TonSwift.PublicKey = try s.loadType()
                let lockupConfig: LockupConfig = try s.loadType()
                return .Lockup(publicKey, lockupConfig)
            case .watchonly:
                let resolvableAddress: ResolvableAddress = try s.loadType()
                return .Watchonly(resolvableAddress)
            case .signer:
                let publicKey: TonSwift.PublicKey = try s.loadType()
                let contractVersion: WalletContractVersion = try s.loadType()
                return .Signer(publicKey, contractVersion)
            case .signerDevice:
                let publicKey: TonSwift.PublicKey = try s.loadType()
                let contractVersion: WalletContractVersion = try s.loadType()
                return .SignerDevice(publicKey, contractVersion)
            case .ledger:
                let publicKey: TonSwift.PublicKey = try s.loadType()
                let contractVersion: WalletContractVersion = try s.loadType()
                let device: Wallet.LedgerDevice = try s.loadType()
                return .Ledger(publicKey, contractVersion, device)
            case .keystone:
                let publicKey: TonSwift.PublicKey = try s.loadType()

                var xfp: String? = nil

                let hasXfp: Bool = try s.loadType()
                if hasXfp {
                    xfp = try String(s.loadUint(bits: 64))
                }
                let contractVersion: WalletContractVersion = try s.loadType()

                var path: String? = nil

                let hasPath: Bool = try s.loadType()
                if hasPath {
                    path = try s.loadSnakeString()
                }
                return .Keystone(publicKey, xfp, path, contractVersion)
            case .watchonlyWithContractVersion:
                let resolvableAddress: ResolvableAddress = try s.loadType()
                let contractVersion: WalletContractVersion = try s.loadType()
                return .Watchonly(resolvableAddress, contractVersion)
            case nil:
                throw TonError.custom("Invalid WalletKind type")
            }
        }
    }
}
