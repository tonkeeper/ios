import Foundation
import Testing
@testable import TronSwift

@Suite
struct MnemonicTests {
    @Test func seedFromMnemonic() {
        let mnemonic = """
        moment repair fork clip dish lawn brain stadium garden quantum surge cloud
        """
        let hexSeed = """
        5ac907db8ff114e92334befce4ec44d83b309e6642af3213acefdedd8d5f5373029941a8fd177258f34df131b6367ca6705e9be031bc0b38b833758d9b08d827
        """
        let array = mnemonic.components(separatedBy: " ")
        let seed = Mnemonic.mnemonicToSeed(mnemonic: array)
        #expect(seed.hexString() == hexSeed)
    }
}
