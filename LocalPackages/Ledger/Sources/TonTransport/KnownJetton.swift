import Foundation
import TonSwift

public struct KnownJetton: Equatable {
    public let jettonId: UInt16
    public let workchain: Int8

    public init(jettonId: UInt16, workchain: Int8) {
        self.jettonId = jettonId
        self.workchain = workchain
    }
}

/// Jettons the TON Ledger app can name on screen. The device identifies one by its index
/// in this list, so the order must match the app's own table; entries the firmware added later
/// carry the version that introduced them, since an older app reads an unknown id past its table.
public enum LedgerKnownJettons {
    struct Entry {
        let master: Address
        let minAppVersion: String

        init(_ master: String, _ minAppVersion: String) {
            self.master = try! Address.parse(master)
            self.minAppVersion = minAppVersion
        }
    }

    private static let baseAppVersion = "2.3.0"
    private static let extendedAppVersion = "2.6.1"

    static let entries: [Entry] = [
        Entry("EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs", baseAppVersion), // USDT
        Entry("EQAvlWFDxGF2lXm67y4yzC17wYKD9A0guwPkMs1gOsM__NOT", baseAppVersion), // NOT
        Entry("EQC98_qAmNEptUtPc7W6xdHh_ZHrBUFpw5Ft_IzNU20QAJav", baseAppVersion), // tsTON
        Entry("EQB0SoxuGDx5qjVt0P_bPICFeWdFLBmVopHhjgfs0q-wsTON", baseAppVersion), // wsTON
        Entry("EQDPdq8xjAhytYqfGSX8KcFWIReCufsB9Wdg0pLlYSO_h76w", baseAppVersion), // hTON
        Entry("EQDNhy-nxYFgUqzfUzImBEP67JqsyMIcyk2S5_RwNNEYku0k", baseAppVersion), // stTON
        Entry("EQCqC6EhRJ_tpWngKxL6dV0k6DSnRUrs9GSVkLbfdCqsj6TE", baseAppVersion), // STAKED
        Entry("EQD-cvR0Nz6XAyRBvbhz-abTrRC6sI5tvHvvpeQraV9UAAD7", extendedAppVersion), // CATI
        Entry("EQCvxJy4eG8hyHBFsZ7eePxrRsUQSFE_jpptRAYBmcG_DOGS", extendedAppVersion), // DOGS
        Entry("EQB4zZusHsbU2vVTPqjhlokIOoiZhEdCMT703CWEzhTOo__X", extendedAppVersion), // X
    ]

    public static func jettonId(master: Address) -> UInt16? {
        entries.firstIndex { $0.master == master }.map { UInt16($0) }
    }

    public static func minAppVersion(jettonId: UInt16) -> String? {
        entries.indices.contains(Int(jettonId)) ? entries[Int(jettonId)].minAppVersion : nil
    }
}
