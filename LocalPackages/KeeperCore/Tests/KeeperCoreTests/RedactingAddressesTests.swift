@testable import KeeperCore
import XCTest

final class RedactingAddressesTests: XCTestCase {
    func test_anAddressOfAnyChainIsRedacted() {
        let cases = [
            "EQD8CPSozp5MN3x8smu6aUjBatSlDRNuzzQQ_HLbPP7ACyfj": "<hex>",
            "UQAYbigAGcESXjUBxp_IObJT_GhoXvTqViGKdNqgeTjcIkVq": "<hex>",
            "sent to EQD8CPSozp5MN3x8smu6aUjBatSlDRNuzzQQ_HLbPP7ACyfj today": "sent to <hex> today",
            "kQDAIGpoaHGTKhQqF_unOsZBbgMYxT4AwJo3O6PDPQE2qX2q": "<hex>",
            "Ef-XW6P2luwm_5HE_rZPVPJQ79R1DkiMY02l4AtuWXJCi2iS": "<hex>",
            "EQDew/9ZUqEmctrWJmefNJDg5iM+0XsCLrJrgGFC7NZYasCR": "<hex>",
            "wallet_EQDew/9ZUqEmctrWJmefNJDg5iM+0XsCLrJrgGFC7NZYasCR": "wallet_<hex>",
            "q=send+EQDew/9ZUqEmctrWJmefNJDg5iM+0XsCLrJrgGFC7NZYasCR&x=1": "q=send+<hex>&x=1",
            "https://app.example/?address=EQDew%2F9ZUqEmctrWJmefNJDg5iM%2b0XsCLrJrgGFC7NZYasCR&x=1": "https://app.example/?address=<hex>&x=1",
            "UQAYbigAGcESXjUBxp_IObJT_GhoXvTqViGKdNqgeTjcIkVq_20240101": "<hex>_20240101",
            "https://tonviewer.com/EQD8CPSozp5MN3x8smu6aUjBatSlDRNuzzQQ_HLbPP7ACyfj/jetton": "https://tonviewer.com/<hex>/jetton",
            "0:27bafbc62e01aedd3fc7261a53b46a4bf314f202ece4503c7306e347525100f3": "0:<hex>",
            "execution reverted for 0x0eE3CdEE4f010BF6c49aF86E9e67ef2bc80a508b": "execution reverted for <hex>",
            "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t": "<hex>",
            "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v": "<hex>",
        ]

        for (text, redacted) in cases {
            XCTAssertEqual(text.redactingAddresses, redacted, text)
        }
    }

    func test_textThatOnlyLooksLikeAnAddressStays() {
        let texts = [
            "the_workflow_for_onboarding_screens_and_more_steps_here",
            "https://docs.example.com/guides/Efficient-staking/v2/how-to-deposit-ton-and-earn-more",
            "EQD8CPSozp5MN3x8smu6aUjB/tSlDRNuzzQQ_HLbPP7ACyfj",
            "carousel_banner_v2",
        ]

        for text in texts {
            XCTAssertEqual(text.redactingAddresses, text)
        }
    }
}
