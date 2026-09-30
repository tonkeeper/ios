import Foundation
import Testing
import TronSwift
@testable import TronSwiftAPI

@Suite
struct AccountTransactionsResponseTests {
    @Test
    func onlyTransferContractCarriesATransfer() throws {
        let json = """
        {
          "data": [
            {
              "ret": [{ "contractRet": "SUCCESS", "fee": 1100000 }],
              "txID": "transfer-id",
              "block_timestamp": 1773698433000,
              "raw_data": {
                "contract": [
                  {
                    "parameter": {
                      "value": {
                        "amount": 2500000,
                        "owner_address": "41a614f803b6fd780986a42c78ec9c7f77e6ded13c",
                        "to_address": "410000000000000000000000000000000000000000"
                      },
                      "type_url": "type.googleapis.com/protocol.TransferContract"
                    },
                    "type": "TransferContract"
                  }
                ]
              }
            },
            {
              "ret": [{ "contractRet": "SUCCESS" }],
              "txID": "trc20-id",
              "block_timestamp": 1773698400000,
              "raw_data": {
                "contract": [
                  {
                    "parameter": {
                      "value": {
                        "data": "a9059cbb",
                        "owner_address": "41a614f803b6fd780986a42c78ec9c7f77e6ded13c",
                        "contract_address": "41a614f803b6fd780986a42c78ec9c7f77e6ded13c"
                      },
                      "type_url": "type.googleapis.com/protocol.TriggerSmartContract"
                    },
                    "type": "TriggerSmartContract"
                  }
                ]
              }
            }
          ],
          "success": true,
          "meta": { "at": 1773753635430, "page_size": 2, "fingerprint": "next-page" }
        }
        """

        let response = try JSONDecoder().decode(AccountTransactionsResponse.self, from: Data(json.utf8))

        #expect(response.fingerprint == "next-page")
        #expect(response.data.count == 2)

        let transfer = try #require(response.data[0].transfer)
        #expect(response.data[0].txID == "transfer-id")
        #expect(response.data[0].timestamp == 1_773_698_433_000)
        #expect(!response.data[0].isFailed)
        #expect(try transfer.from == Address(address: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"))
        #expect(try transfer.to == Address(address: "T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb"))
        #expect(transfer.amountSun == 2_500_000)

        #expect(response.data[1].transfer == nil)
    }

    @Test
    func resultOtherThanSuccessMarksFailure_missingResultDoesNot() throws {
        let json = """
        {
          "data": [
            {
              "ret": [{ "contractRet": "OUT_OF_ENERGY" }],
              "txID": "failed-id",
              "block_timestamp": 1,
              "raw_data": { "contract": [] }
            },
            {
              "txID": "unconfirmed-id",
              "block_timestamp": 2,
              "raw_data": { "contract": [] }
            }
          ],
          "success": true,
          "meta": { "at": 3 }
        }
        """

        let response = try JSONDecoder().decode(AccountTransactionsResponse.self, from: Data(json.utf8))

        #expect(response.data[0].isFailed)
        #expect(!response.data[1].isFailed)
        #expect(response.fingerprint == nil)
    }
}
