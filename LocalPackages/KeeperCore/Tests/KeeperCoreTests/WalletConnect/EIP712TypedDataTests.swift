@testable import KeeperCore
import WalletCore
import XCTest

final class EIP712TypedDataTests: XCTestCase {
    func testTheSpecMailHashesAsTheSpecSays() throws {
        let typedData = try EIP712TypedData(json: Self.mail)

        XCTAssertEqual(typedData.domainSeparator.hexString(), "f2cee375fa42b42143804025fc449deafd50cc031ca257e0b194a650a912090f")
        XCTAssertEqual(typedData.messageHash.hexString(), "c52c0ee5d84264471806290a3f2c4cecfc5490626bf912d01f240d7a274b371e")
        XCTAssertEqual(typedData.digest.hexString(), "be609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2")
        XCTAssertEqual(typedData.digest, EthereumAbi.encodeTyped(messageJson: Self.mail))
    }

    func testArraysBytesAndNumbersHashAsWalletCoreHashesThem() throws {
        let json = """
        {"types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"chainId","type":"uint256"},{"name":"verifyingContract","type":"address"}],\
        "Person":[{"name":"name","type":"string"},{"name":"wallets","type":"address[]"}],\
        "Order":[{"name":"maker","type":"Person"},{"name":"takers","type":"Person[]"},{"name":"data","type":"bytes"},\
        {"name":"amount","type":"uint256"},{"name":"delta","type":"int256"},{"name":"flags","type":"bool[]"},{"name":"salt","type":"bytes32"},{"name":"deadline","type":"uint48"}]},\
        "primaryType":"Order",\
        "domain":{"name":"Permit2","chainId":"0x2105","verifyingContract":"0x000000000022D473030F116dDEE9F6B43aC78BA3"},\
        "message":{"maker":{"name":"Alice","wallets":["0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"]},\
        "takers":[{"name":"Bob","wallets":["0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB","0xB0B0b0b0b0b0B000000000000000000000000000"]}],\
        "data":"0xdeadbeef","amount":"115792089237316195423570985008687907853269984665640564039457584007913129639935",\
        "delta":"-42","flags":[true,false],"salt":"0x0102","deadline":1735689600}}
        """

        let typedData = try EIP712TypedData(json: json)

        XCTAssertEqual(typedData.digest, EthereumAbi.encodeTyped(messageJson: json))
    }

    func testDataWhoseOnlyTypeIsTheDomainIsRefused() {
        let json = """
        {"types":{"EIP712Domain":[{"name":"name","type":"string"}]},"primaryType":"EIP712Domain","domain":{"name":"A"},"message":{}}
        """

        XCTAssertThrowsError(try EIP712TypedData(json: json))
    }

    func testAMissingAtomicValueIsRefused() {
        let json = Self.mail.replacingOccurrences(of: "\"contents\":\"Hello, Bob!\"", with: "\"other\":1")

        XCTAssertThrowsError(try EIP712TypedData(json: json))
    }

    private static let mail = """
    {"types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"version","type":"string"},{"name":"chainId","type":"uint256"},\
    {"name":"verifyingContract","type":"address"}],"Person":[{"name":"name","type":"string"},{"name":"wallet","type":"address"}],\
    "Mail":[{"name":"from","type":"Person"},{"name":"to","type":"Person"},{"name":"contents","type":"string"}]},"primaryType":"Mail",\
    "domain":{"name":"Ether Mail","version":"1","chainId":1,"verifyingContract":"0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"},\
    "message":{"from":{"name":"Cow","wallet":"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},\
    "to":{"name":"Bob","wallet":"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},"contents":"Hello, Bob!"}}
    """
}
