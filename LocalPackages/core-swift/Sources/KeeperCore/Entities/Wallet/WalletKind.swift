import Foundation
import TonSwift

public enum WalletKind: Codable, Equatable, Hashable {
    case Regular(TonSwift.PublicKey, WalletContractVersion)
    case Lockup(TonSwift.PublicKey, LockupConfig)
    case Watchonly(ResolvableAddress)
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
        case let (.Watchonly(laddress), .Watchonly(raddress)):
            return laddress == raddress
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
    public func storeTo(builder: Builder) throws {
        switch self {
        case let .Regular(publicKey, contractVersion):
            try builder.store(uint: 0, bits: 5)
            try publicKey.storeTo(builder: builder)
            try contractVersion.storeTo(builder: builder)
        case let .Lockup(publicKey, lockupConfig):
            try builder.store(uint: 1, bits: 5)
            try publicKey.storeTo(builder: builder)
            try lockupConfig.storeTo(builder: builder)
        case let .Watchonly(resolvableAddress):
            try builder.store(uint: 2, bits: 5)
            try resolvableAddress.storeTo(builder: builder)
        case let .Signer(publicKey, contractVersion):
            try builder.store(uint: 3, bits: 5)
            try publicKey.storeTo(builder: builder)
            try contractVersion.storeTo(builder: builder)
        case let .SignerDevice(publicKey, contractVersion):
            try builder.store(uint: 4, bits: 5)
            try publicKey.storeTo(builder: builder)
            try contractVersion.storeTo(builder: builder)
        case let .Ledger(publicKey, contractVersion, device):
            try builder.store(uint: 5, bits: 5)
            try publicKey.storeTo(builder: builder)
            try contractVersion.storeTo(builder: builder)
            try device.storeTo(builder: builder)
        case let .Keystone(publicKey, xfp, path, contractVersion):
            try builder.store(uint: 6, bits: 5)
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
            let type = try s.loadUint(bits: 5)
            switch type {
            case 0:
                let publicKey: TonSwift.PublicKey = try s.loadType()
                let contractVersion: WalletContractVersion = try s.loadType()
                return .Regular(publicKey, contractVersion)
            case 1:
                let publicKey: TonSwift.PublicKey = try s.loadType()
                let lockupConfig: LockupConfig = try s.loadType()
                return .Lockup(publicKey, lockupConfig)
            case 2:
                let resolvableAddress: ResolvableAddress = try s.loadType()
                return .Watchonly(resolvableAddress)
            case 3:
                let publicKey: TonSwift.PublicKey = try s.loadType()
                let contractVersion: WalletContractVersion = try s.loadType()
                return .Signer(publicKey, contractVersion)
            case 4:
                let publicKey: TonSwift.PublicKey = try s.loadType()
                let contractVersion: WalletContractVersion = try s.loadType()
                return .SignerDevice(publicKey, contractVersion)
            case 5:
                let publicKey: TonSwift.PublicKey = try s.loadType()
                let contractVersion: WalletContractVersion = try s.loadType()
                let device: Wallet.LedgerDevice = try s.loadType()
                return .Ledger(publicKey, contractVersion, device)
            case 6:
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
            default:
                throw TonError.custom("Invalid WalletKind type")
            }
        }
    }
}
