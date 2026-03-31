import Foundation
import Testing
@testable import TronSwift

@Suite
struct HDKeysTests {
    @Test func mnemonicToKeysPair() throws {
        let mnemonic = """
        moment repair fork clip dish lawn brain stadium garden quantum surge cloud
        """
        let array = mnemonic.components(separatedBy: " ")
        let keyPair = HDKeys.keyPair(mnemonic: array, derivationCurve: Secp256k1DerivationCurve())
        let derivedPrivateKey44Hardened = try keyPair.privateKey.deriveKey(index: 44, hardened: true, curve: Secp256k1DerivationCurve())
        #expect(derivedPrivateKey44Hardened.hexString == "1fcc12bd49f538d2d58d135abe9c9897fd675a658092c447936d507a840d1b25")
        let derivedPrivateKey195Hardened = try derivedPrivateKey44Hardened.deriveKey(index: 195, hardened: true, curve: Secp256k1DerivationCurve())
        #expect(derivedPrivateKey195Hardened.hexString == "a3cc2b2a0474d5c5fd89f4e4ddcdc743ecd724a824bcb53b3b2bd53ec1c4d271")
        let derivedPrivateKey0Hardened = try derivedPrivateKey195Hardened.deriveKey(index: 0, hardened: true, curve: Secp256k1DerivationCurve())
        #expect(derivedPrivateKey0Hardened.hexString == "4e8d972bb3c545d7b69e0764a084659d75354940e194dfe03fcdfde621362cc0")
        let derivedPrivateKey0 = try derivedPrivateKey0Hardened.deriveKey(index: 0, hardened: false, curve: Secp256k1DerivationCurve())
        #expect(derivedPrivateKey0.hexString == "5d1e31f05e0b965bdf7d1cb3826a3af54516ad083743e0f60f04816d94392fcb")
    }

    @Test func mnemonicToKeysPairTron0Index() throws {
        let mnemonic = """
        moment repair fork clip dish lawn brain stadium garden quantum surge cloud
        """
        let array = mnemonic.components(separatedBy: " ")
        let keyPair = try HDKeys.derivedKeyPair(
            mnemonic: array,
            purpose: 44,
            coin: 195,
            account: 0,
            chain: 0,
            index: 0,
            derivationCurve: Secp256k1DerivationCurve()
        )
        #expect(keyPair.privateKey.hexString == "2bd300eab885bea3199ea26fb1841ca2a1b7b93b9fd7a2ec959a6d3867873d0c")
        #expect(keyPair.publicKey.hexString == "04e05e76d638c8287f1ca7b49c94944aa8e7c3dffe33afb9221fee527e95de487aa75f5f766976b2c542b7fd800053ffe85f0c0992640bf7c8493af25669b1e969")
    }
}
