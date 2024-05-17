import XCTest
import TonSwift
import BigInt
@testable import SignerCore

final class TransferParserImplementationTests: XCTestCase {
  
  func test_transfer_parser_implementation_parse_ton_transfer_with_comment() throws {
    // GIVEN
    let boc = """
    te6cckECFwEAA70AA+OIAaCWRZEz0juYPLOJ1N0qXc7NyuHvHI6gopWn/fHekUY4EY1/yb16VgKKDvx1iyQBcZBRc+8bve0byVmhRoklIIJrB3fHdbsfI6JWrFOd0u4PXN6eQKIS5udAJkKhcZ2U7UAlNTRi/////+AAAAAAAHADAgEAimIANGCPrsViEggIytj510yztlODXwsRvzSswdaIzflUSASQnEAAAAAAAAAAAAAAAAAAAAAAAHRoaXMgaXMgY29tbWVudABRAAAAACmpoxcADlkEPOY/76yVZbq8N3FJBS6uydU0uwwwdzEnBhXZqUABFP8A9KQT9LzyyAsEAgEgCgUE+PKDCNcYINMf0x/THwL4I7vyZO1E0NMf0x/T//QE0VFDuvKhUVG68qIF+QFUEGT5EPKj+AAkpMjLH1JAyx9SMMv/UhD0AMntVPgPAdMHIcAAn2xRkyDXSpbTB9QC+wDoMOAhwAHjACHAAuMAAcADkTDjDQOkyMsfEssfy/8JCAcGAAr0AMntVABsgQEI1xj6ANM/MFIkgQEI9Fnyp4IQZHN0cnB0gBjIywXLAlAFzxZQA/oCE8tqyx8Syz/Jc/sAAHCBAQjXGPoA0z/IVCBHgQEI9FHyp4IQbm90ZXB0gBjIywXLAlAGzxZQBPoCFMtqEssfyz/Jc/sAAgBu0gf6ANTUIvkABcjKBxXL/8nQd3SAGMjLBcsCIs8WUAX6AhTLaxLMzMlz+wDIQBSBAQj0UfKnAgIBSBQLAgEgDQwAWb0kK29qJoQICga5D6AhhHDUCAhHpJN9KZEM5pA+n/mDeBKAG3gQFImHFZ8xhAIBIA8OABG4yX7UTQ1wsfgCAVgTEAIBIBIRABmvHfaiaEAQa5DrhY/AABmtznaiaEAga5Drhf/AAD2ynftRNCBAUDXIfQEMALIygfL/8nQAYEBCPQKb6ExgAubQAdDTAyFxsJJfBOAi10nBIJJfBOAC0x8hghBwbHVnvSKCEGRzdHK9sJJfBeAD+kAwIPpEAcjKB8v/ydDtRNCBAUDXIfQEMFyBAQj0Cm+hMbOSXwfgBdM/yCWCEHBsdWe6kjgw4w0DghBkc3RyupJfBuMNFhUAilAEgQEI9Fkw7UTQgQFA1yDIAc8W9ADJ7VQBcrCOI4IQZHN0coMesXCAGFAFywVQA88WI/oCE8tqyx/LP8mAQPsAkl8D4gB4AfoA9AQw+CdvIjBQCqEhvvLgUIIQcGx1Z4MesXCAGFAEywUmzxZY+gIZ9ADLaRfLH1Jgyz8gyYBA+wAGsT6sQg==
    """
    let cell = try Cell.fromBase64(src: boc)
    let parser = TransferParserImplementation()
    
    let senderAddress: Address = try .parse(
      raw: "0:d04b22c899e91dcc1e59c4ea6e952ee766e570f78e4750514ad3fef8ef48a31c"
    )
    let amount: BigUInt = "000005000"
    let recipientAddress: Address = try .parse(
      raw: "0:68c11f5d8ac424101195b1f3ae99676ca706be16237e695983ad119bf2a89009"
    )
    let comment = "this is comment"
    let transferModel = TransferModel(
      senderAddress: senderAddress,
      transfers: [
        .tonTransfer(
          .init(amount: amount,
                recipientAddress: recipientAddress,
                comment: comment)
        )
      ])
    
    // WHEN
    let parsedTransferModel = try parser.parseTransfer(transfer: cell)
    
    // THEN
    XCTAssertEqual(parsedTransferModel.senderAddress, transferModel.senderAddress)
    XCTAssertEqual(parsedTransferModel.transfers.count, transferModel.transfers.count)
    switch parsedTransferModel.transfers.first {
    case .tonTransfer(let model):
      XCTAssertEqual(model.amount, amount)
      XCTAssertEqual(model.recipientAddress, recipientAddress)
      XCTAssertEqual(model.comment, comment)
    default:
      XCTFail()
    }
  }
  
  func test_transfer_parser_implementation_parse_ton_transfer_without_comment() throws {
    // GIVEN
    let boc = """
    te6cckECFwEAA6wAA+OIAaCWRZEz0juYPLOJ1N0qXc7NyuHvHI6gopWn/fHekUY4EYwgTBSPAeVWsw2TshIKODxU7CZX7S23jl3HgfudxFcVfA/pXWTS+D7Apg/h58sQbdhrrTwlL3vYksrslJ8oDeClNTRi/////+AAAAAAAHADAgEAaGIANGCPrsViEggIytj510yztlODXwsRvzSswdaIzflUSASgHJw4AAAAAAAAAAAAAAAAAAAAUQAAAAApqaMXAA5ZBDzmP++slWW6vDdxSQUursnVNLsMMHcxJwYV2alAART/APSkE/S88sgLBAIBIAoFBPjygwjXGCDTH9Mf0x8C+CO78mTtRNDTH9Mf0//0BNFRQ7ryoVFRuvKiBfkBVBBk+RDyo/gAJKTIyx9SQMsfUjDL/1IQ9ADJ7VT4DwHTByHAAJ9sUZMg10qW0wfUAvsA6DDgIcAB4wAhwALjAAHAA5Ew4w0DpMjLHxLLH8v/CQgHBgAK9ADJ7VQAbIEBCNcY+gDTPzBSJIEBCPRZ8qeCEGRzdHJwdIAYyMsFywJQBc8WUAP6AhPLassfEss/yXP7AABwgQEI1xj6ANM/yFQgR4EBCPRR8qeCEG5vdGVwdIAYyMsFywJQBs8WUAT6AhTLahLLH8s/yXP7AAIAbtIH+gDU1CL5AAXIygcVy//J0Hd0gBjIywXLAiLPFlAF+gIUy2sSzMzJc/sAyEAUgQEI9FHypwICAUgUCwIBIA0MAFm9JCtvaiaECAoGuQ+gIYRw1AgIR6STfSmRDOaQPp/5g3gSgBt4EBSJhxWfMYQCASAPDgARuMl+1E0NcLH4AgFYExACASASEQAZrx32omhAEGuQ64WPwAAZrc52omhAIGuQ64X/wAA9sp37UTQgQFA1yH0BDACyMoHy//J0AGBAQj0Cm+hMYALm0AHQ0wMhcbCSXwTgItdJwSCSXwTgAtMfIYIQcGx1Z70ighBkc3RyvbCSXwXgA/pAMCD6RAHIygfL/8nQ7UTQgQFA1yH0BDBcgQEI9ApvoTGzkl8H4AXTP8glghBwbHVnupI4MOMNA4IQZHN0crqSXwbjDRYVAIpQBIEBCPRZMO1E0IEBQNcgyAHPFvQAye1UAXKwjiOCEGRzdHKDHrFwgBhQBcsFUAPPFiP6AhPLassfyz/JgED7AJJfA+IAeAH6APQEMPgnbyIwUAqhIb7y4FCCEHBsdWeDHrFwgBhQBMsFJs8WWPoCGfQAy2kXyx9SYMs/IMmAQPsABom64TY=
    """
    let cell = try Cell.fromBase64(src: boc)
    let parser = TransferParserImplementation()
    
    let senderAddress: Address = try .parse(
      raw: "0:d04b22c899e91dcc1e59c4ea6e952ee766e570f78e4750514ad3fef8ef48a31c"
    )
    let amount: BigUInt = "060000000"
    let recipientAddress: Address = try .parse(
      raw: "0:68c11f5d8ac424101195b1f3ae99676ca706be16237e695983ad119bf2a89009"
    )
    let transferModel = TransferModel(
      senderAddress: senderAddress,
      transfers: [
        .tonTransfer(
          .init(amount: amount,
                recipientAddress: recipientAddress,
                comment: nil)
        )
      ])
    
    // WHEN
    let parsedTransferModel = try parser.parseTransfer(transfer: cell)
    
    // THEN
    XCTAssertEqual(parsedTransferModel.senderAddress, transferModel.senderAddress)
    XCTAssertEqual(parsedTransferModel.transfers.count, transferModel.transfers.count)
    switch parsedTransferModel.transfers.first {
    case .tonTransfer(let model):
      XCTAssertEqual(model.amount, amount)
      XCTAssertEqual(model.recipientAddress, recipientAddress)
      XCTAssertEqual(model.comment, nil)
    default:
      XCTFail()
    }
  }
  
  func test_transfer_parser_implementation_parse_jetton_transfer_with_comment() throws {
    // GIVEN
    let boc = """
    te6cckECGQEABBgAA+OIAaCWRZEz0juYPLOJ1N0qXc7NyuHvHI6gopWn/fHekUY4EYH6yOOMpGbh2/Jrrj8zlegp3QhX/cVTL6B3g9lYj0HqaOF2a1HfpUvHYMdcO7U/M1xkY7VZxyLRULJ6EiqvaqFFNTRi/////+AAAAAAAHAFBAEBaGIAJwsk2m0acoq7L687qps0rmKsFEu3jI4ILEEHJY9dJnUhMS0AAAAAAAAAAAAAAAAAAAECAaoPin6lAAABjCcvrSdDuaygCADRgj67FYhIICMrY+ddMs7ZTg18LEb80rMHWiM35VEgEwA0EsiyJnpHcweWcTqbpUu52blcPeOR1BRStP++O9IoxwIDAwAiAAAAAGl0J3MgY29tbWVudCEAUQAAAAApqaMXAA5ZBDzmP++slWW6vDdxSQUursnVNLsMMHcxJwYV2alAART/APSkE/S88sgLBgIBIAwHBPjygwjXGCDTH9Mf0x8C+CO78mTtRNDTH9Mf0//0BNFRQ7ryoVFRuvKiBfkBVBBk+RDyo/gAJKTIyx9SQMsfUjDL/1IQ9ADJ7VT4DwHTByHAAJ9sUZMg10qW0wfUAvsA6DDgIcAB4wAhwALjAAHAA5Ew4w0DpMjLHxLLH8v/CwoJCAAK9ADJ7VQAbIEBCNcY+gDTPzBSJIEBCPRZ8qeCEGRzdHJwdIAYyMsFywJQBc8WUAP6AhPLassfEss/yXP7AABwgQEI1xj6ANM/yFQgR4EBCPRR8qeCEG5vdGVwdIAYyMsFywJQBs8WUAT6AhTLahLLH8s/yXP7AAIAbtIH+gDU1CL5AAXIygcVy//J0Hd0gBjIywXLAiLPFlAF+gIUy2sSzMzJc/sAyEAUgQEI9FHypwICAUgWDQIBIA8OAFm9JCtvaiaECAoGuQ+gIYRw1AgIR6STfSmRDOaQPp/5g3gSgBt4EBSJhxWfMYQCASAREAARuMl+1E0NcLH4AgFYFRICASAUEwAZrx32omhAEGuQ64WPwAAZrc52omhAIGuQ64X/wAA9sp37UTQgQFA1yH0BDACyMoHy//J0AGBAQj0Cm+hMYALm0AHQ0wMhcbCSXwTgItdJwSCSXwTgAtMfIYIQcGx1Z70ighBkc3RyvbCSXwXgA/pAMCD6RAHIygfL/8nQ7UTQgQFA1yH0BDBcgQEI9ApvoTGzkl8H4AXTP8glghBwbHVnupI4MOMNA4IQZHN0crqSXwbjDRgXAIpQBIEBCPRZMO1E0IEBQNcgyAHPFvQAye1UAXKwjiOCEGRzdHKDHrFwgBhQBcsFUAPPFiP6AhPLassfyz/JgED7AJJfA+IAeAH6APQEMPgnbyIwUAqhIb7y4FCCEHBsdWeDHrFwgBhQBMsFJs8WWPoCGfQAy2kXyx9SYMs/IMmAQPsABgnrDx8=
    """
    
    let cell = try Cell.fromBase64(src: boc)
    let senderAddress: Address = try .parse(
      raw: "0:d04b22c899e91dcc1e59c4ea6e952ee766e570f78e4750514ad3fef8ef48a31c"
    )
    let amount: BigUInt = "1000000000"
    let jettonAddress: Address = try .parse(
      raw: "0:4e1649b4da34e515765f5e775536695cc55828976f191c1058820e4b1eba4cea"
    )
    let recipientAddress: Address = try .parse(
      raw: "0:68c11f5d8ac424101195b1f3ae99676ca706be16237e695983ad119bf2a89009"
    )
    let comment = "it's comment!"
    let transferModel = TransferModel(
      senderAddress: senderAddress,
      transfers: [
        .jettonTransfer(
          .init(amount: amount,
                jettonAddress: jettonAddress,
                recipientAddress: recipientAddress,
                comment: comment)
        )
      ])
    let parser = TransferParserImplementation()
    
    // WHEN
    let parsedTransferModel = try parser.parseTransfer(transfer: cell)
    
    // THEN
    XCTAssertEqual(parsedTransferModel.senderAddress, transferModel.senderAddress)
    XCTAssertEqual(parsedTransferModel.transfers.count, transferModel.transfers.count)
    switch parsedTransferModel.transfers.first {
    case .jettonTransfer(let model):
      XCTAssertEqual(model.amount, amount)
      XCTAssertEqual(model.jettonAddress, jettonAddress)
      XCTAssertEqual(model.recipientAddress, recipientAddress)
      XCTAssertEqual(model.comment, comment)
    default:
      XCTFail()
    }
  }
  
  func test_transfer_parser_implementation_parse_jetton_transfer_without_comment() throws {
    // GIVEN
    let boc = """
    te6cckECGAEABAQAA+OIAaCWRZEz0juYPLOJ1N0qXc7NyuHvHI6gopWn/fHekUY4EY+MmdpfIg8G09bhJyxiC7DYI7D+73yMgnsh5VV2212FMnyKCqHH/04nhvcbXj85bAZzvsaCqWIRjzdt30/B5+HFNTRi/////+AAAAAAAHAEAwEBaGIAJwsk2m0acoq7L687qps0rmKsFEu3jI4ILEEHJY9dJnUhMS0AAAAAAAAAAAAAAAAAAAECAKoPin6lAAABjCcwVUVDuaygCADRgj67FYhIICMrY+ddMs7ZTg18LEb80rMHWiM35VEgEwA0EsiyJnpHcweWcTqbpUu52blcPeOR1BRStP++O9IoxwICAFEAAAAAKamjFwAOWQQ85j/vrJVlurw3cUkFLq7J1TS7DDB3MScGFdmpQAEU/wD0pBP0vPLICwUCASALBgT48oMI1xgg0x/TH9MfAvgju/Jk7UTQ0x/TH9P/9ATRUUO68qFRUbryogX5AVQQZPkQ8qP4ACSkyMsfUkDLH1Iwy/9SEPQAye1U+A8B0wchwACfbFGTINdKltMH1AL7AOgw4CHAAeMAIcAC4wABwAORMOMNA6TIyx8Syx/L/woJCAcACvQAye1UAGyBAQjXGPoA0z8wUiSBAQj0WfKnghBkc3RycHSAGMjLBcsCUAXPFlAD+gITy2rLHxLLP8lz+wAAcIEBCNcY+gDTP8hUIEeBAQj0UfKnghBub3RlcHSAGMjLBcsCUAbPFlAE+gIUy2oSyx/LP8lz+wACAG7SB/oA1NQi+QAFyMoHFcv/ydB3dIAYyMsFywIizxZQBfoCFMtrEszMyXP7AMhAFIEBCPRR8qcCAgFIFQwCASAODQBZvSQrb2omhAgKBrkPoCGEcNQICEekk30pkQzmkD6f+YN4EoAbeBAUiYcVnzGEAgEgEA8AEbjJftRNDXCx+AIBWBQRAgEgExIAGa8d9qJoQBBrkOuFj8AAGa3OdqJoQCBrkOuF/8AAPbKd+1E0IEBQNch9AQwAsjKB8v/ydABgQEI9ApvoTGAC5tAB0NMDIXGwkl8E4CLXScEgkl8E4ALTHyGCEHBsdWe9IoIQZHN0cr2wkl8F4AP6QDAg+kQByMoHy//J0O1E0IEBQNch9AQwXIEBCPQKb6Exs5JfB+AF0z/IJYIQcGx1Z7qSODDjDQOCEGRzdHK6kl8G4w0XFgCKUASBAQj0WTDtRNCBAUDXIMgBzxb0AMntVAFysI4jghBkc3Rygx6xcIAYUAXLBVADzxYj+gITy2rLH8s/yYBA+wCSXwPiAHgB+gD0BDD4J28iMFAKoSG+8uBQghBwbHVngx6xcIAYUATLBSbPFlj6Ahn0AMtpF8sfUmDLPyDJgED7AAZeurFK
    """
    
    let cell = try Cell.fromBase64(src: boc)
    let senderAddress: Address = try .parse(
      raw: "0:d04b22c899e91dcc1e59c4ea6e952ee766e570f78e4750514ad3fef8ef48a31c"
    )
    let amount: BigUInt = "1000000000"
    let jettonAddress: Address = try .parse(
      raw: "0:4e1649b4da34e515765f5e775536695cc55828976f191c1058820e4b1eba4cea"
    )
    let recipientAddress: Address = try .parse(
      raw: "0:68c11f5d8ac424101195b1f3ae99676ca706be16237e695983ad119bf2a89009"
    )
    let transferModel = TransferModel(
      senderAddress: senderAddress,
      transfers: [
        .jettonTransfer(
          .init(amount: amount,
                jettonAddress: jettonAddress,
                recipientAddress: recipientAddress,
                comment: nil)
        )
      ])
    let parser = TransferParserImplementation()
    
    // WHEN
    let parsedTransferModel = try parser.parseTransfer(transfer: cell)
    
    // THEN
    XCTAssertEqual(parsedTransferModel.senderAddress, transferModel.senderAddress)
    XCTAssertEqual(parsedTransferModel.transfers.count, transferModel.transfers.count)
    switch parsedTransferModel.transfers.first {
    case .jettonTransfer(let model):
      XCTAssertEqual(model.amount, amount)
      XCTAssertEqual(model.jettonAddress, jettonAddress)
      XCTAssertEqual(model.recipientAddress, recipientAddress)
      XCTAssertEqual(model.comment, nil)
    default:
      XCTFail()
    }
  }
  
  func test_transfer_parser_implementation_parse_nft_transfer_with_comment() throws {
    // GIVEN
    let boc = """
    te6cckECGQEABBsAA+OIAaCWRZEz0juYPLOJ1N0qXc7NyuHvHI6gopWn/fHekUY4EZcRUxbJQnAjhABUDRkooBaDVbTf4FLznuobZoDo+hNdMyd5DPXLH2vdhsC1vJeMUuB9I6NapTDasK+xI/C6YOBFNTRi/////+AAAAAAAHAFBAEBaGIAHOpXdq6QTPuB9UPo3+8z7QmSl4u2ooDBFId/gDUatDeh3NZQAAAAAAAAAAAAAAAAAAECAaFfzD0UAAABjCc50baADRgj67FYhIICMrY+ddMs7ZTg18LEb80rMHWiM35VEgEwA0EsiyJnpHcweWcTqbpUu52blcPeOR1BRStP++O9IoxwIDgDADAAAAAAbmZ0IHRyYW5zZmVyIGNvbW1lbnQAUQAAAAApqaMXAA5ZBDzmP++slWW6vDdxSQUursnVNLsMMHcxJwYV2alAART/APSkE/S88sgLBgIBIAwHBPjygwjXGCDTH9Mf0x8C+CO78mTtRNDTH9Mf0//0BNFRQ7ryoVFRuvKiBfkBVBBk+RDyo/gAJKTIyx9SQMsfUjDL/1IQ9ADJ7VT4DwHTByHAAJ9sUZMg10qW0wfUAvsA6DDgIcAB4wAhwALjAAHAA5Ew4w0DpMjLHxLLH8v/CwoJCAAK9ADJ7VQAbIEBCNcY+gDTPzBSJIEBCPRZ8qeCEGRzdHJwdIAYyMsFywJQBc8WUAP6AhPLassfEss/yXP7AABwgQEI1xj6ANM/yFQgR4EBCPRR8qeCEG5vdGVwdIAYyMsFywJQBs8WUAT6AhTLahLLH8s/yXP7AAIAbtIH+gDU1CL5AAXIygcVy//J0Hd0gBjIywXLAiLPFlAF+gIUy2sSzMzJc/sAyEAUgQEI9FHypwICAUgWDQIBIA8OAFm9JCtvaiaECAoGuQ+gIYRw1AgIR6STfSmRDOaQPp/5g3gSgBt4EBSJhxWfMYQCASAREAARuMl+1E0NcLH4AgFYFRICASAUEwAZrx32omhAEGuQ64WPwAAZrc52omhAIGuQ64X/wAA9sp37UTQgQFA1yH0BDACyMoHy//J0AGBAQj0Cm+hMYALm0AHQ0wMhcbCSXwTgItdJwSCSXwTgAtMfIYIQcGx1Z70ighBkc3RyvbCSXwXgA/pAMCD6RAHIygfL/8nQ7UTQgQFA1yH0BDBcgQEI9ApvoTGzkl8H4AXTP8glghBwbHVnupI4MOMNA4IQZHN0crqSXwbjDRgXAIpQBIEBCPRZMO1E0IEBQNcgyAHPFvQAye1UAXKwjiOCEGRzdHKDHrFwgBhQBcsFUAPPFiP6AhPLassfyz/JgED7AJJfA+IAeAH6APQEMPgnbyIwUAqhIb7y4FCCEHBsdWeDHrFwgBhQBMsFJs8WWPoCGfQAy2kXyx9SYMs/IMmAQPsABgYbY2U=
    """
    
    let cell = try Cell.fromBase64(src: boc)
    let senderAddress: Address = try .parse(
      raw: "0:d04b22c899e91dcc1e59c4ea6e952ee766e570f78e4750514ad3fef8ef48a31c"
    )
    let nftAddress: Address = try .parse(
      raw: "0:39d4aeed5d2099f703ea87d1bfde67da13252f176d450182290eff006a35686f"
    )
    let recipientAddress: Address = try .parse(
      raw: "0:68c11f5d8ac424101195b1f3ae99676ca706be16237e695983ad119bf2a89009"
    )
    let comment = "nft transfer comment"
    let transferModel = TransferModel(
      senderAddress: senderAddress,
      transfers: [
        .nftTransfer(
          .init(nftAddress: nftAddress,
                recipientAddress: recipientAddress,
                comment: comment)
        )
      ])
    let parser = TransferParserImplementation()
    
    // WHEN
    let parsedTransferModel = try parser.parseTransfer(transfer: cell)
    
    // THEN
    XCTAssertEqual(parsedTransferModel.senderAddress, transferModel.senderAddress)
    XCTAssertEqual(parsedTransferModel.transfers.count, transferModel.transfers.count)
    switch parsedTransferModel.transfers.first {
    case .nftTransfer(let model):
      XCTAssertEqual(model.nftAddress, nftAddress)
      XCTAssertEqual(model.recipientAddress, recipientAddress)
      XCTAssertEqual(model.comment, comment)
    default:
      XCTFail()
    }
  }
  
  func test_transfer_parser_implementation_parse_nft_transfer_without_comment() throws {
    // GIVEN
    let boc = """
    te6cckECGAEABAAAA+OIAaCWRZEz0juYPLOJ1N0qXc7NyuHvHI6gopWn/fHekUY4EZPy8HpfP/jsWtspzhUBeF9/DoRQgyJaSpRs8i/HxHwM4ibciiGLxLzbRlcyLx0ggmz0egQVNe/nCAWre88g2sAFNTRi/////+AAAAAAAHAEAwEBaGIAHOpXdq6QTPuB9UPo3+8z7QmSl4u2ooDBFId/gDUatDeh3NZQAAAAAAAAAAAAAAAAAAECAKFfzD0UAAABjCc70SiADRgj67FYhIICMrY+ddMs7ZTg18LEb80rMHWiM35VEgEwA0EsiyJnpHcweWcTqbpUu52blcPeOR1BRStP++O9IoxwICgAUQAAAAApqaMXAA5ZBDzmP++slWW6vDdxSQUursnVNLsMMHcxJwYV2alAART/APSkE/S88sgLBQIBIAsGBPjygwjXGCDTH9Mf0x8C+CO78mTtRNDTH9Mf0//0BNFRQ7ryoVFRuvKiBfkBVBBk+RDyo/gAJKTIyx9SQMsfUjDL/1IQ9ADJ7VT4DwHTByHAAJ9sUZMg10qW0wfUAvsA6DDgIcAB4wAhwALjAAHAA5Ew4w0DpMjLHxLLH8v/CgkIBwAK9ADJ7VQAbIEBCNcY+gDTPzBSJIEBCPRZ8qeCEGRzdHJwdIAYyMsFywJQBc8WUAP6AhPLassfEss/yXP7AABwgQEI1xj6ANM/yFQgR4EBCPRR8qeCEG5vdGVwdIAYyMsFywJQBs8WUAT6AhTLahLLH8s/yXP7AAIAbtIH+gDU1CL5AAXIygcVy//J0Hd0gBjIywXLAiLPFlAF+gIUy2sSzMzJc/sAyEAUgQEI9FHypwICAUgVDAIBIA4NAFm9JCtvaiaECAoGuQ+gIYRw1AgIR6STfSmRDOaQPp/5g3gSgBt4EBSJhxWfMYQCASAQDwARuMl+1E0NcLH4AgFYFBECASATEgAZrx32omhAEGuQ64WPwAAZrc52omhAIGuQ64X/wAA9sp37UTQgQFA1yH0BDACyMoHy//J0AGBAQj0Cm+hMYALm0AHQ0wMhcbCSXwTgItdJwSCSXwTgAtMfIYIQcGx1Z70ighBkc3RyvbCSXwXgA/pAMCD6RAHIygfL/8nQ7UTQgQFA1yH0BDBcgQEI9ApvoTGzkl8H4AXTP8glghBwbHVnupI4MOMNA4IQZHN0crqSXwbjDRcWAIpQBIEBCPRZMO1E0IEBQNcgyAHPFvQAye1UAXKwjiOCEGRzdHKDHrFwgBhQBcsFUAPPFiP6AhPLassfyz/JgED7AJJfA+IAeAH6APQEMPgnbyIwUAqhIb7y4FCCEHBsdWeDHrFwgBhQBMsFJs8WWPoCGfQAy2kXyx9SYMs/IMmAQPsABvpIfSQ=
    """
    
    let cell = try Cell.fromBase64(src: boc)
    let senderAddress: Address = try .parse(
      raw: "0:d04b22c899e91dcc1e59c4ea6e952ee766e570f78e4750514ad3fef8ef48a31c"
    )
    let nftAddress: Address = try .parse(
      raw: "0:39d4aeed5d2099f703ea87d1bfde67da13252f176d450182290eff006a35686f"
    )
    let recipientAddress: Address = try .parse(
      raw: "0:68c11f5d8ac424101195b1f3ae99676ca706be16237e695983ad119bf2a89009"
    )
    let transferModel = TransferModel(
      senderAddress: senderAddress,
      transfers: [
        .nftTransfer(
          .init(nftAddress: nftAddress,
                recipientAddress: recipientAddress,
                comment: nil)
        )
      ])
    let parser = TransferParserImplementation()
    
    // WHEN
    let parsedTransferModel = try parser.parseTransfer(transfer: cell)
    
    // THEN
    XCTAssertEqual(parsedTransferModel.senderAddress, transferModel.senderAddress)
    XCTAssertEqual(parsedTransferModel.transfers.count, transferModel.transfers.count)
    switch parsedTransferModel.transfers.first {
    case .nftTransfer(let model):
      XCTAssertEqual(model.nftAddress, nftAddress)
      XCTAssertEqual(model.recipientAddress, recipientAddress)
      XCTAssertEqual(model.comment, nil)
    default:
      XCTFail()
    }
  }
}
