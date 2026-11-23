@testable import KeeperCore
import XCTest

final class UniqueKeyJSONTests: XCTestCase {
    /// `\u` escapes put together at run time: written in the source, an editor may decode them.
    private func escaped(_ codeUnits: String...) -> String {
        codeUnits.map { "\\" + "u" + $0 }.joined()
    }

    func testADocumentNamingEveryKeyOnceIsRead() {
        let documents = [
            #"{"domain":{"name":"Hermes","chainId":1},"message":{"calls":[{"target":"0x1","value":"0"},{"target":"0x2","value":"0"}],"nonce":"5"}}"#,
            #"  {"a":[1,-2.5,3e10,0.1E-2,true,false,null,""# + escaped("00e9", "d83d", "de00") + #"\n"],"b":{}}  "#,
            #"{""# + escaped("006d") + #"essage":1,"messages":2}"#,
            #"[]"#,
            #""text""#,
            "-0",
        ]
        for document in documents {
            XCTAssertTrue(UniqueKeyJSON.isWellFormed(document), document)
        }
    }

    func testAKeyRepeatedAtAnyLevelIsRefused() {
        let documents = [
            #"{"message":{"calls":[]},"message":{"calls":[]}}"#,
            #"{"domain":{"name":"Hermes","name":"Other"}}"#,
            #"{"message":{"calls":[{"target":"0x1","target":"0x2"}]}}"#,
            #"[{"a":1},{"b":2,"b":3}]"#,
        ]
        for document in documents {
            XCTAssertFalse(UniqueKeyJSON.isWellFormed(document), document)
        }
    }

    /// Both decoders read the escapes before they compare keys.
    func testAKeyRepeatedThroughAnEscapeIsRefused() {
        let documents = [
            #"{""# + escaped("006d") + #"essage":1,"message":2}"#,
            #"{""# + escaped("00e9") + #"":1,"é":2}"#,
            #"{""# + escaped("d83d", "de00") + #"":1,"😀":2}"#,
            #"{"a\/b":1,"a/b":2}"#,
        ]
        for document in documents {
            XCTAssertFalse(UniqueKeyJSON.isWellFormed(document), document)
        }
    }

    func testAnythingButOneWellFormedValueIsRefused() {
        let documents = [
            "",
            #"{"a":1} {"a":2}"#,
            #"{"a":1,}"#,
            #"{"a" 1}"#,
            #"{a:1}"#,
            #"{"a":01}"#,
            #"{"a":1.}"#,
            #"{"a":tru}"#,
            #"{"a":""# + escaped("d800") + #""}"#,
            #"{"a":"\x"}"#,
            "{\"a\":\"line\nbreak\"}",
            String(repeating: "[", count: 100) + String(repeating: "]", count: 100),
        ]
        for document in documents {
            XCTAssertFalse(UniqueKeyJSON.isWellFormed(document), document)
        }
    }
}
