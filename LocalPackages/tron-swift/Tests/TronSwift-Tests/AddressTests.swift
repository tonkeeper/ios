import Foundation
import Testing
@testable import TronSwift

@Suite
struct AddressTests {
    @Test
    func addressRawInit() throws {
        let base64 = "Qdeog3+i1n+K5g8BWQVYyd7s+aDn"
        let data = try #require(Data(base64Encoded: base64))
        let address = try Address(raw: data)
        let base58Address = "TVdW9qX4kyXb9jFoUwXJswtEqKHdn85AVd"
        #expect(address.base58 == base58Address)
    }

    @Test
    func addressFromMnemonic() throws {
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
        let address = try Address(publicKey: keyPair.publicKey)
        #expect(address.base58 == "TVdW9qX4kyXb9jFoUwXJswtEqKHdn85AVd")
    }
}
