@preconcurrency import AnyCodable
import BigInt
import Foundation
@testable import KeeperCore
import XCTest

final class WalletConnectMethodParserTests: XCTestCase {
    private let parser = WalletConnectMethodParser()

    func testPersonalSignParsing() throws {
        let parsed = try parser.parse(
            method: "personal_sign",
            chain: "eip155:1",
            paramsJSON: #"["0x68656c6c6f","0xabc"]"#
        )

        XCTAssertEqual(parsed.method, .personalSign)
        XCTAssertEqual(parsed.chain, .eth)
        XCTAssertEqual(
            parsed.payload,
            .signMessage(WalletConnectSignMessage(address: "0xabc", message: "0x68656c6c6f", kind: .personal))
        )
    }

    func testTypedDataV4ParsingValidatesChainId() throws {
        let typedData = #"{"types":{},"domain":{"chainId":1},"primaryType":"Mail","message":{}}"#
        let paramsJSON = #"[ "0xabc", "\#(typedData.replacingOccurrences(of: "\"", with: "\\\""))" ]"#

        let parsed = try parser.parse(
            method: "eth_signTypedData_v4",
            chain: "eip155:1",
            paramsJSON: paramsJSON
        )

        XCTAssertEqual(parsed.method, .ethSignTypedDataV4)
        XCTAssertEqual(parsed.chain, .eth)
        XCTAssertEqual(
            parsed.payload,
            .signMessage(WalletConnectSignMessage(address: "0xabc", message: typedData, kind: .typedDataV4))
        )
    }

    func testTypedDataV4ParsingRejectsMismatchedChainId() throws {
        let typedData = #"{"types":{},"domain":{"chainId":56},"primaryType":"Mail","message":{}}"#
        let paramsJSON = #"[ "0xabc", "\#(typedData.replacingOccurrences(of: "\"", with: "\\\""))" ]"#

        XCTAssertThrowsError(try parser.parse(
            method: "eth_signTypedData_v4",
            chain: "eip155:1",
            paramsJSON: paramsJSON
        )) { error in
            XCTAssertEqual(error as? WalletConnectRequestParsingError, .chainMismatch(expected: .eth, actual: "56"))
        }
    }

    func testTypedDataV4ParsingRejectsLargeUInt256MismatchedChainId() throws {
        let largeChainId = "340282366920938463463374607431768211455"
        let typedData = #"{"types":{},"domain":{"chainId":"\#(largeChainId)"},"primaryType":"Mail","message":{}}"#
        let paramsJSON = #"[ "0xabc", "\#(typedData.replacingOccurrences(of: "\"", with: "\\\""))" ]"#

        XCTAssertThrowsError(try parser.parse(
            method: "eth_signTypedData_v4",
            chain: "eip155:1",
            paramsJSON: paramsJSON
        )) { error in
            XCTAssertEqual(error as? WalletConnectRequestParsingError, .chainMismatch(expected: .eth, actual: largeChainId))
        }
    }

    func testTypedDataV4ParsingIgnoresNonUInt256ChainId() throws {
        let typedData = #"{"types":{},"domain":{"chainId":{"unexpected":1}},"primaryType":"Mail","message":{}}"#
        let paramsJSON = #"[ "0xabc", "\#(typedData.replacingOccurrences(of: "\"", with: "\\\""))" ]"#

        let parsed = try parser.parse(
            method: "eth_signTypedData_v4",
            chain: "eip155:1",
            paramsJSON: paramsJSON
        )

        XCTAssertEqual(
            parsed.payload,
            .signMessage(WalletConnectSignMessage(address: "0xabc", message: typedData, kind: .typedDataV4))
        )
    }

    func testTypedDataV4ParsingAcceptsTypedDataWithoutDomainChainId() throws {
        for typedData in [
            #"{"types":{},"domain":{"name":"USD Coin"},"primaryType":"Mail","message":{}}"#,
            #"{"types":{},"primaryType":"Mail","message":{}}"#,
        ] {
            let paramsJSON = #"[ "0xabc", "\#(typedData.replacingOccurrences(of: "\"", with: "\\\""))" ]"#

            let parsed = try parser.parse(
                method: "eth_signTypedData_v4",
                chain: "eip155:1",
                paramsJSON: paramsJSON
            )

            XCTAssertEqual(
                parsed.payload,
                .signMessage(WalletConnectSignMessage(address: "0xabc", message: typedData, kind: .typedDataV4)),
                typedData
            )
        }
    }

    func testTypedDataV4ParsingAcceptsHexChainIdOfTheRequestedChain() throws {
        let typedData = #"{"types":{},"domain":{"chainId":"0x2105"},"primaryType":"Mail","message":{}}"#
        let paramsJSON = #"[ "0xabc", "\#(typedData.replacingOccurrences(of: "\"", with: "\\\""))" ]"#

        let parsed = try parser.parse(
            method: "eth_signTypedData_v4",
            chain: "eip155:8453",
            paramsJSON: paramsJSON
        )

        XCTAssertEqual(parsed.chain, .base)
        XCTAssertEqual(
            parsed.payload,
            .signMessage(WalletConnectSignMessage(address: "0xabc", message: typedData, kind: .typedDataV4))
        )
    }

    func testTypedDataV4ParsingRejectsHexChainIdOfAnotherChain() throws {
        let typedData = #"{"types":{},"domain":{"chainId":"0x38"},"primaryType":"Mail","message":{}}"#
        let paramsJSON = #"[ "0xabc", "\#(typedData.replacingOccurrences(of: "\"", with: "\\\""))" ]"#

        XCTAssertThrowsError(try parser.parse(
            method: "eth_signTypedData_v4",
            chain: "eip155:1",
            paramsJSON: paramsJSON
        )) { error in
            XCTAssertEqual(error as? WalletConnectRequestParsingError, .chainMismatch(expected: .eth, actual: "56"))
        }
    }

    func testEthSendTransactionParsing() throws {
        let parsed = try parser.parse(
            method: "eth_sendTransaction",
            chain: "eip155:8453",
            paramsJSON: #"""
            [
                {
                    "from": "0xabc",
                    "to": "0xdef",
                    "value": "0x1",
                    "data": "0x",
                    "gasLimit": "0x5208"
                }
            ]
            """#
        )

        XCTAssertEqual(parsed.method, .ethSendTransaction)
        XCTAssertEqual(parsed.chain, .base)
        XCTAssertEqual(
            parsed.payload,
            .evmTransaction(
                WalletConnectEVMTransaction(
                    from: "0xabc",
                    to: "0xdef",
                    data: "0x",
                    value: "0x1",
                    nonce: nil,
                    gas: "0x5208",
                    gasPrice: nil,
                    maxFeePerGas: nil,
                    maxPriorityFeePerGas: nil
                ),
                send: true
            )
        )
    }

    func testEthSendTransactionRejectsTronChain() throws {
        XCTAssertThrowsError(try parser.parse(
            method: "eth_sendTransaction",
            chain: "tron:0x2b6653dc",
            paramsJSON: "[]"
        )) { error in
            XCTAssertEqual(
                error as? WalletConnectRequestParsingError,
                .unsupportedMethod(WalletConnectMethod.ethSendTransaction.rawValue)
            )
        }
    }

    func testSwitchEthereumChainParsing() throws {
        let parsed = try parser.parse(
            method: "wallet_switchEthereumChain",
            chain: "eip155:1",
            paramsJSON: #"[{"chainId":"0x2105"}]"#
        )

        XCTAssertEqual(parsed.method, .walletSwitchEthereumChain)
        XCTAssertEqual(parsed.chain, .eth)
        XCTAssertEqual(parsed.payload, .switchEthereumChain(.base))
    }

    func testSwitchEthereumChainRejectsBadParams() throws {
        let invalidParams = [
            #"[]"#,
            #"[{"chainId":"8453"}]"#,
            #"[{"chainId":"0x"}]"#,
            #"[{"chainId":"0xzz"}]"#,
        ]

        for paramsJSON in invalidParams {
            XCTAssertThrowsError(try parser.parse(
                method: "wallet_switchEthereumChain",
                chain: "eip155:1",
                paramsJSON: paramsJSON
            )) { error in
                guard case .invalidParams = error as? WalletConnectRequestParsingError else {
                    XCTFail("Expected invalid params for \(paramsJSON), got \(error)")
                    return
                }
            }
        }
    }

    func testSwitchEthereumChainRejectsUnsupportedChain() throws {
        XCTAssertThrowsError(try parser.parse(
            method: "wallet_switchEthereumChain",
            chain: "eip155:1",
            paramsJSON: #"[{"chainId":"0x999999"}]"#
        )) { error in
            XCTAssertEqual(
                error as? WalletConnectRequestParsingError,
                .unsupportedChain("eip155:10066329")
            )
        }
    }

    func testWalletGetCapabilitiesParsingUsesRequestedChainIds() throws {
        let parsed = try parser.parse(
            method: "wallet_getCapabilities",
            chain: "eip155:1",
            paramsJSON: #"["0xabc",["0x1","0x2105","0xaa36a7"]]"#
        )

        XCTAssertEqual(parsed.method, .walletGetCapabilities)
        XCTAssertEqual(parsed.chain, .eth)
        XCTAssertEqual(
            parsed.payload,
            .walletCapabilities(WalletConnectWalletCapabilitiesRequest(
                address: "0xabc",
                chainIds: ["0x1", "0x2105", "0xaa36a7"]
            ))
        )
    }

    func testWalletGetCapabilitiesParsingFallsBackToRequestChain() throws {
        let paramsValues = [
            #"["0xabc"]"#,
            #"["0xabc",[]]"#,
            #"["0xabc",null]"#,
        ]

        for paramsJSON in paramsValues {
            let parsed = try parser.parse(
                method: "wallet_getCapabilities",
                chain: "eip155:8453",
                paramsJSON: paramsJSON
            )

            XCTAssertEqual(
                parsed.payload,
                .walletCapabilities(WalletConnectWalletCapabilitiesRequest(
                    address: "0xabc",
                    chainIds: ["0x2105"]
                )),
                paramsJSON
            )
        }
    }

    func testWalletGetCapabilitiesParsingPreservesNonCanonicalHexChainIds() throws {
        let parsed = try parser.parse(
            method: "wallet_getCapabilities",
            chain: "eip155:1",
            paramsJSON: #"["0xabc",["0x01","0X2105"]]"#
        )

        XCTAssertEqual(
            parsed.payload,
            .walletCapabilities(WalletConnectWalletCapabilitiesRequest(
                address: "0xabc",
                chainIds: ["0x01", "0X2105"]
            ))
        )
    }

    func testWalletGetCapabilitiesRejectsInvalidParams() throws {
        let invalidParams = [
            #"[]"#,
            #"[1]"#,
            #"["0xabc","0x1"]"#,
            #"["0xabc",["1"]]"#,
            #"["0xabc",[" 0x1 "]]"#,
            #"["0xabc",["0x"]]"#,
            #"["0xabc",["0xzz"]]"#,
            #"["0xabc",["0x\#u{FF11}"]]"#,
            #"["0xabc",[],{}]"#,
        ]

        for paramsJSON in invalidParams {
            XCTAssertThrowsError(try parser.parse(
                method: "wallet_getCapabilities",
                chain: "eip155:1",
                paramsJSON: paramsJSON
            )) { error in
                guard case .invalidParams = error as? WalletConnectRequestParsingError else {
                    XCTFail("Expected invalid params for \(paramsJSON), got \(error)")
                    return
                }
            }
        }
    }

    func testEthSignTransactionParsing() throws {
        let parsed = try parser.parse(
            method: "eth_signTransaction",
            chain: "eip155:1",
            paramsJSON: #"""
            [
                {
                    "from": "0xabc",
                    "to": "0xdef",
                    "value": "0x2",
                    "data": "0x1234",
                    "gas": "0x5208"
                }
            ]
            """#
        )

        XCTAssertEqual(parsed.method, .ethSignTransaction)
        XCTAssertEqual(parsed.chain, .eth)
        XCTAssertEqual(
            parsed.payload,
            .evmTransaction(
                WalletConnectEVMTransaction(
                    from: "0xabc",
                    to: "0xdef",
                    data: "0x1234",
                    value: "0x2",
                    nonce: nil,
                    gas: "0x5208",
                    gasPrice: nil,
                    maxFeePerGas: nil,
                    maxPriorityFeePerGas: nil
                ),
                send: false
            )
        )
    }

    func testEVMQuantityValidationRejectsInvalidValue() throws {
        let transaction = try parseEVMTransaction(paramsJSON: #"""
        [
            {
                "from": "0xabc",
                "to": "0xdef",
                "value": "0xzz",
                "data": "0x"
            }
        ]
        """#)

        XCTAssertThrowsError(try transaction.requiredEVMQuantity(.value)) { error in
            XCTAssertEqual(
                error as? WalletConnectSigningError,
                .invalidTransaction(reason: "invalid EVM quantity value: 0xzz")
            )
        }
    }

    func testEVMQuantityValidationRejectsInvalidNonce() throws {
        let transaction = try parseEVMTransaction(paramsJSON: #"""
        [
            {
                "from": "0xabc",
                "to": "0xdef",
                "value": "0x0",
                "data": "0x",
                "nonce": "latest"
            }
        ]
        """#)

        XCTAssertThrowsError(try transaction.optionalEVMQuantity(.nonce)) { error in
            XCTAssertEqual(
                error as? WalletConnectSigningError,
                .invalidTransaction(reason: "invalid EVM quantity nonce: latest")
            )
        }
    }

    func testEVMQuantityValidationAllowsLeadingZeros() throws {
        let transaction = try parseEVMTransaction(paramsJSON: #"""
        [
            {
                "from": "0xabc",
                "to": "0xdef",
                "value": "0x00",
                "data": "0x",
                "nonce": "0x09",
                "gas": "0x05208",
                "gasPrice": "0x013e3d2ed4",
                "maxFeePerGas": "0x064",
                "maxPriorityFeePerGas": "0x02"
            }
        ]
        """#)

        XCTAssertEqual(try transaction.requiredEVMQuantity(.value), 0)
        XCTAssertEqual(try transaction.optionalEVMQuantity(.nonce), 9)
        XCTAssertEqual(try transaction.optionalEVMQuantity(.gas), 21000)
        XCTAssertEqual(try transaction.optionalEVMQuantity(.gasPrice), BigUInt("5339164372"))
        XCTAssertEqual(try transaction.optionalEVMQuantity(.maxFeePerGas), 100)
        XCTAssertEqual(try transaction.optionalEVMQuantity(.maxPriorityFeePerGas), 2)
    }

    func testEVMQuantityValidationRejectsInvalidGasAndFeeFields() throws {
        let invalidFields: [(jsonKey: String, quantityField: WalletConnectEVMQuantityField)] = [
            ("gas", .gas),
            ("gasPrice", .gasPrice),
            ("maxFeePerGas", .maxFeePerGas),
            ("maxPriorityFeePerGas", .maxPriorityFeePerGas),
        ]

        for invalidField in invalidFields {
            let transaction = try parseEVMTransaction(paramsJSON: #"""
            [
                {
                    "from": "0xabc",
                    "to": "0xdef",
                    "value": "0x0",
                    "data": "0x",
                    "\#(invalidField.jsonKey)": "0x0x"
                }
            ]
            """#)

            XCTAssertThrowsError(try transaction.optionalEVMQuantity(invalidField.quantityField)) { error in
                XCTAssertEqual(
                    error as? WalletConnectSigningError,
                    .invalidTransaction(reason: "invalid EVM quantity \(invalidField.quantityField.rawValue): 0x0x")
                )
            }
        }
    }

    func testRequestFeeRejectsInvalidFeeFieldWhenGasIsMissing() throws {
        let invalidFields: [(jsonKey: String, quantityField: WalletConnectEVMQuantityField)] = [
            ("gasPrice", .gasPrice),
            ("maxFeePerGas", .maxFeePerGas),
            ("maxPriorityFeePerGas", .maxPriorityFeePerGas),
        ]

        for invalidField in invalidFields {
            let transaction = try parseEVMTransaction(paramsJSON: #"""
            [
                {
                    "from": "0xabc",
                    "to": "0xdef",
                    "value": "0x0",
                    "data": "0x",
                    "\#(invalidField.jsonKey)": "0x0x"
                }
            ]
            """#)

            XCTAssertThrowsError(try WalletConnectRequestFeeFactory.requestFee(payload: transaction, chain: .eth)) { error in
                XCTAssertEqual(
                    error as? WalletConnectSigningError,
                    .invalidTransaction(reason: "invalid EVM quantity \(invalidField.quantityField.rawValue): 0x0x")
                )
            }
        }
    }

    func testEVMQuantityValidationRejectsNullOptionalQuantity() throws {
        let transaction = try parseEVMTransaction(paramsJSON: #"""
        [
            {
                "from": "0xabc",
                "to": "0xdef",
                "value": "0x0",
                "data": "0x",
                "nonce": null
            }
        ]
        """#)

        XCTAssertThrowsError(try transaction.optionalEVMQuantity(.nonce)) { error in
            XCTAssertEqual(
                error as? WalletConnectSigningError,
                .invalidTransaction(reason: "invalid EVM quantity nonce: null")
            )
        }
    }

    func testEVMQuantityValidationKeepsMissingOptionalFieldsMissing() throws {
        let transaction = try parseEVMTransaction(paramsJSON: #"""
        [
            {
                "from": "0xabc",
                "to": "0xdef",
                "value": "0x0",
                "data": "0x"
            }
        ]
        """#)

        XCTAssertNil(try transaction.optionalEVMQuantity(.nonce))
        XCTAssertNil(try transaction.optionalEVMQuantity(.gas))
        XCTAssertNil(try transaction.optionalEVMQuantity(.gasPrice))
        XCTAssertNil(try transaction.optionalEVMQuantity(.maxFeePerGas))
        XCTAssertNil(try transaction.optionalEVMQuantity(.maxPriorityFeePerGas))
    }

    func testTronSignMessageParsing() throws {
        let parsed = try parser.parse(
            method: "tron_signMessage",
            chain: "tron:0x2b6653dc",
            paramsJSON: #"{"address":"TXUEmLr","message":"hello"}"#
        )

        XCTAssertEqual(parsed.method, .tronSignMessage)
        XCTAssertEqual(parsed.chain, .tron)
        XCTAssertEqual(
            parsed.payload,
            .signMessage(WalletConnectSignMessage(address: "TXUEmLr", message: "hello", kind: .tron))
        )
    }

    func testTronSignTransactionLegacyParsing() throws {
        let parsed = try parser.parse(
            method: "tron_signTransaction",
            chain: "tron:0x2b6653dc",
            paramsJSON: #"""
            {
                "address": "TXUEmLr",
                "transaction": {
                    "transaction": {
                        "raw_data_hex": "0a02",
                        "txID": "ad406961a6518e07ac4e40031f9e4e0486f443208da45ef02e336c3d4a0a50bb"
                    }
                }
            }
            """#
        )

        XCTAssertEqual(parsed.method, .tronSignTransaction)
        XCTAssertEqual(parsed.chain, .tron)
        XCTAssertEqual(
            parsed.payload,
            .tronTransaction(WalletConnectTronTransaction(
                address: "TXUEmLr",
                transactionJSON: AnyCodable([
                    "raw_data_hex": "0a02",
                    "txID": "ad406961a6518e07ac4e40031f9e4e0486f443208da45ef02e336c3d4a0a50bb",
                ] as [String: String]),
                rawDataHex: "0a02",
                txID: "ad406961a6518e07ac4e40031f9e4e0486f443208da45ef02e336c3d4a0a50bb"
            ))
        )

        guard case let .tronTransaction(transaction) = parsed.payload else {
            return XCTFail("Expected tron transaction payload")
        }
        var object = try XCTUnwrap(transaction.transactionJSON.walletConnectObjectValue)
        object["signature"] = ["signature"]
        let data = try JSONEncoder().encode(AnyCodable(object))
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(encoded["raw_data_hex"] as? String, "0a02")
        XCTAssertEqual(encoded["txID"] as? String, "ad406961a6518e07ac4e40031f9e4e0486f443208da45ef02e336c3d4a0a50bb")
        XCTAssertEqual(encoded["signature"] as? [String], ["signature"])
    }

    func testTronSignTransactionV1Parsing() throws {
        let parsed = try parser.parse(
            method: "tron_signTransaction",
            chain: "tron:0x2b6653dc",
            paramsJSON: #"""
            {
                "address": "TXUEmLr",
                "transaction": {
                    "visible": false,
                    "raw_data": {
                        "timestamp": 1756201512720
                    },
                    "raw_data_hex": "0a02",
                    "txID": "ad406961a6518e07ac4e40031f9e4e0486f443208da45ef02e336c3d4a0a50bb"
                }
            }
            """#
        )

        XCTAssertEqual(parsed.method, .tronSignTransaction)
        XCTAssertEqual(parsed.chain, .tron)

        guard case let .tronTransaction(transaction) = parsed.payload else {
            return XCTFail("Expected tron transaction payload")
        }
        XCTAssertEqual(transaction.address, "TXUEmLr")
        XCTAssertEqual(transaction.rawDataHex, "0a02")
        XCTAssertEqual(transaction.txID, "ad406961a6518e07ac4e40031f9e4e0486f443208da45ef02e336c3d4a0a50bb")
        let object = try XCTUnwrap(transaction.transactionJSON.walletConnectObjectValue)
        XCTAssertEqual(object["raw_data_hex"] as? String, "0a02")
        XCTAssertEqual(object["txID"] as? String, "ad406961a6518e07ac4e40031f9e4e0486f443208da45ef02e336c3d4a0a50bb")
        XCTAssertEqual(object["visible"] as? Bool, false)
        XCTAssertNotNil(object["raw_data"] as? [String: Any])
    }

    func testTronSignTransactionRejectsMismatchedTxID() throws {
        XCTAssertThrowsError(try parser.parse(
            method: "tron_signTransaction",
            chain: "tron:0x2b6653dc",
            paramsJSON: #"""
            {
                "address": "TXUEmLr",
                "transaction": {
                    "visible": false,
                    "raw_data_hex": "0a02",
                    "txID": "deadbeef"
                }
            }
            """#
        )) { error in
            XCTAssertEqual(
                error as? WalletConnectRequestParsingError,
                .invalidParams(method: .tronSignTransaction, reason: "tron transaction txID does not match raw_data_hex")
            )
        }
    }

    func testTronSignTransactionRejectsEIP155Chain() throws {
        XCTAssertThrowsError(try parser.parse(
            method: "tron_signTransaction",
            chain: "eip155:1",
            paramsJSON: "{}"
        )) { error in
            XCTAssertEqual(
                error as? WalletConnectRequestParsingError,
                .unsupportedMethod(WalletConnectMethod.tronSignTransaction.rawValue)
            )
        }
    }

    func testTONSendMessageParsing() throws {
        let paramsJSON = #"""
        [
            {
                "from": "EQDmnxDMhId6v1Ofg_h5KR5coWlFG6e86Ro3pc7Tq4CA0-Jn",
                "messages": [
                    {
                        "address": "EQC6rPmY7J7_0i2DhUw-1aA6OR77nT3JX0B4vRk0O_GD6nJL",
                        "amount": "1000000",
                        "payload": "te6cckEBAQEAAwAAAgE="
                    }
                ]
            }
        ]
        """#

        let parsed = try parser.parse(
            method: "ton_sendMessage",
            chain: "ton:-239",
            paramsJSON: paramsJSON
        )

        XCTAssertEqual(parsed.method, .tonSendMessage)
        XCTAssertEqual(parsed.chain, .ton)
        XCTAssertEqual(
            parsed.payload,
            .tonSendMessage(WalletConnectTONSendMessage(
                from: "EQDmnxDMhId6v1Ofg_h5KR5coWlFG6e86Ro3pc7Tq4CA0-Jn",
                messagesCount: 1,
                rawParamsJSON: paramsJSON
            ))
        )
    }

    func testTONSignDataParsing() throws {
        let paramsJSON = #"""
        [
            {
                "type": "text",
                "text": "hello",
                "address": "EQDmnxDMhId6v1Ofg_h5KR5coWlFG6e86Ro3pc7Tq4CA0-Jn"
            }
        ]
        """#

        let parsed = try parser.parse(
            method: "ton_signData",
            chain: "ton:-239",
            paramsJSON: paramsJSON
        )

        XCTAssertEqual(parsed.method, .tonSignData)
        XCTAssertEqual(parsed.chain, .ton)
        XCTAssertEqual(
            parsed.payload,
            .tonSignData(WalletConnectTONSignData(
                address: "EQDmnxDMhId6v1Ofg_h5KR5coWlFG6e86Ro3pc7Tq4CA0-Jn",
                payload: .text("hello"),
                rawParamsJSON: paramsJSON
            ))
        )
    }

    func testTONMethodRejectsEIP155Chain() throws {
        XCTAssertThrowsError(try parser.parse(
            method: "ton_signData",
            chain: "eip155:1",
            paramsJSON: #"[]"#
        )) { error in
            XCTAssertEqual(
                error as? WalletConnectRequestParsingError,
                .unsupportedMethod(WalletConnectMethod.tonSignData.rawValue)
            )
        }
    }

    private func parseEVMTransaction(paramsJSON: String) throws -> WalletConnectEVMTransaction {
        let parsed = try parser.parse(
            method: "eth_sendTransaction",
            chain: "eip155:1",
            paramsJSON: paramsJSON
        )

        guard case let .evmTransaction(transaction, _) = parsed.payload else {
            throw XCTSkip("Expected EVM transaction payload")
        }
        return transaction
    }
}
