import BigInt
import Foundation
import Testing
@testable import TronSwiftAPI

struct TronAccountBalancesResponseTests {
    @Test
    func accountResponseMapsTrxAndUsdtFromOneAccount() throws {
        let json = """
        {
          "data": [
            {
              "balance": 1234567,
              "trc20": [
                { "other-token": "10" },
                { "tr7nhqjekqxgtci8q8zy4pl8otszgjlj6t": "12345678901234567890" }
              ]
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(
            TronAccountBalancesResponse.self,
            from: Data(json.utf8)
        )
        let balances = response.balances(
            usdtContractAddress: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
        )

        #expect(balances.trxAmount == 1_234_567)
        #expect(balances.usdtAmount == BigUInt("12345678901234567890"))
    }

    @Test
    func emptyAccountListMapsToZeroBalances() throws {
        let response = try JSONDecoder().decode(
            TronAccountBalancesResponse.self,
            from: Data(#"{"data":[]}"#.utf8)
        )

        let balances = response.balances(
            usdtContractAddress: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
        )

        #expect(balances == TronAccountBalances(trxAmount: 0, usdtAmount: 0))
    }

    @Test
    func negativeOrMissingBalancesMapToZero() throws {
        let json = """
        {
          "data": [
            {
              "balance": -1,
              "trc20": [
                { "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t": "-2" }
              ]
            }
          ]
        }
        """
        let response = try JSONDecoder().decode(
            TronAccountBalancesResponse.self,
            from: Data(json.utf8)
        )

        let balances = response.balances(
            usdtContractAddress: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
        )

        #expect(balances == TronAccountBalances(trxAmount: 0, usdtAmount: 0))
    }
}
