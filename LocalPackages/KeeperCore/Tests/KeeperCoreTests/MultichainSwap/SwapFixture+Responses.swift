import Foundation

/// The swap API's `/v3/crosschain` answers recorded from the backend, by the name a test asks
/// `SwapFixture.data(_:)` for: each recorded swap's quote and the route it prepared.
extension SwapFixture {
    static let responses: [String: String] = [
        "confirm_v3_prepare_btc_eth": #"""
        {
          "route_id": "73da9a8c-5d26-4002-9298-d8d61349c301",
          "provider_route_id": "0x86cebfba8f0bc1e2ee3df376187b6aad9d88b4ab7648d606049f1048ef7af768",
          "aggregator": "swapsxyz",
          "execution_id": "5146a1ff-3ef7-43b5-b30e-30922c045b19",
          "operation": {
            "id": "73da9a8c-5d26-4002-9298-d8d61349c301",
            "payloads": [
              {
                "id": "828936e0-0daa-414e-b057-76acd0f7be28",
                "type": "main",
                "chain_id": "btc/mainnet",
                "version": 1,
                "meta": {
                  "to": "3FHycwXWPjdpMubBrsugoFdwLGiSNBR4WJ",
                  "value": "100000"
                },
                "amount_editable": true
              }
            ]
          },
          "human_summary": {
            "action": "Swap BTC for ETH",
            "spend_asset": "btc/mainnet/coin",
            "spend_amount": "100000",
            "receive_asset": "eth/mainnet/coin",
            "receive_amount": "33346700000000000",
            "minimum_receive_amount": "33013233000000000",
            "protocol": "alt-vm-1"
          },
          "validation_status": "validated",
          "date_expire": "2026-11-02T15:50:46Z"
        }
        """#,
        "confirm_v3_prepare_ton_usdt": #"""
        {
          "route_id": "036bb244-764a-4cb0-b5b8-8e1362551794",
          "aggregator": "omniston",
          "execution_id": "2d4c0861-02f2-4477-bb15-8747dc399838",
          "operation": {
            "id": "036bb244-764a-4cb0-b5b8-8e1362551794",
            "payloads": [
              {
                "id": "63ff0764-ef20-4570-9877-1cbf3de61bd0",
                "type": "main",
                "chain_id": "ton/mainnet",
                "version": 1,
                "meta": {
                  "value": "1280000000",
                  "body": "te6cckECBQEAAWoAAiGlp8v4ZLJHK4lAWzxDuaygCAECABnEQlAPMR4KYAAAAAABAdOAHhy8XXiXPILNhsg+k1kS5GhxIfsU6txsk5vAlEEVC1loFXUqAUALXMdcMUMp6BCaRG4+NP0bqZn72kNWnz3NRatcDdZ/KoAgBa5jrhihlPQITSI3Hxp+jdTM/e0hq0+e5qLVrgbrP5VEAwHRGjwvw4AWuY64YoZT0CE0iNx8afo3UzP3tIatPnuai1a4G6z+VRAC1zHXDFDKegQmkRuPjT9G6mZ+9pDVp89zUWrXA3WfyqIAWuY64YoZT0CE0iNx8afo3UzP3tIatPnuai1a4G6z+VRABADVgARIDnuQ+iIAbCRNs0OZ1VE6NwSTezc2RYwCdmukLh9pYAjQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAECoLIsh",
                  "to": "EQAH4MY1EbqP7Gg2wJkoZvoCG4BYPsEG5lVBXPZn0UqXNz4y"
                }
              }
            ]
          },
          "human_summary": {
            "action": "Swap on TON",
            "spend_asset": "ton/mainnet/coin",
            "spend_amount": "1000000000",
            "receive_asset": "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe",
            "receive_amount": "1183456",
            "recipient_address": "0:b5cc75c314329e8109a446e3e34fd1ba999fbda43569f3dcd45ab5c0dd67f2a8",
            "protocol": "omniston"
          },
          "validation_status": "validated",
          "date_expire": "2026-11-02T15:50:28Z"
        }
        """#,
        "confirm_v3_prepare_usdteth_eth": #"""
        {
          "route_id": "9462c7d9-637c-460e-8a36-a883c00b6f40",
          "provider_route_id": "0xf4a6c7d60c9852471d571261da4cc5c9da056120aaf8edec34371b6b09967d0c",
          "aggregator": "swapsxyz",
          "execution_id": "e15ee324-67d5-43bd-a6b6-614909491bf1",
          "operation": {
            "id": "9462c7d9-637c-460e-8a36-a883c00b6f40",
            "payloads": [
              {
                "id": "62f4f101-9be6-4400-a671-eb6caa5f5332",
                "type": "main",
                "chain_id": "eth/mainnet",
                "version": 1,
                "fee": {
                  "type": "gas",
                  "asset_id": "eth/mainnet/coin",
                  "data": {
                    "price": "301418031",
                    "limit": "63617"
                  }
                },
                "meta": {
                  "to": "0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "value": "0",
                  "data": "0x095ea7b30000000000000000000000001b6257cae4192e62b629efca21771be3d759183d0000000000000000000000000000000000000000000000000000000001312d00"
                }
              },
              {
                "id": "6626b85b-3990-4e43-8f54-6d7737fd8bf2",
                "type": "main",
                "chain_id": "eth/mainnet",
                "version": 1,
                "fee": {
                  "type": "gas",
                  "asset_id": "eth/mainnet/coin",
                  "data": {
                    "price": "301418031"
                  }
                },
                "meta": {
                  "data": "0x9be111d100000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000044000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000ee3cdee4f010bf6c49af86e9e67ef2bc80a508b0000000000000000000000000ee3cdee4f010bf6c49af86e9e67ef2bc80a508b0000000000000000000000000ee3cdee4f010bf6c49af86e9e67ef2bc80a508b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000280f4a6c7d60c9852471d571261da4cc5c9da056120aaf8edec34371b6b09967d0c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000012ebc00000000000000000000000000000000000000000000000000001e8144788be1db0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ee3cdee4f010bf6c49af86e9e67ef2bc80a508b0000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000002bdac17f958d2ee523a2206206994597c13d831ec7000064c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006b8cc2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aea0297000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000079ad858cdff50ca6728d2531894001f221e805c7000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000000271000000000000000000000000000000000000000000000000000000000000000041b6c9cb8c25e8da2560b241d1d537d8eb357c9cc1d14bcc42892ae6536aa8096b6f5d75fd7308ab5a1cc7ffd83a039b8823b38689c5db252496e2a39f575f345b1b00000000000000000000000000000000000000000000000000000000000000",
                  "to": "0x1b6257CAE4192e62B629eFCa21771be3D759183D",
                  "value": "0"
                }
              }
            ]
          },
          "human_summary": {
            "action": "Swap USDT for ETH",
            "spend_asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
            "spend_amount": "20000000",
            "receive_asset": "eth/mainnet/coin",
            "receive_amount": "8673111496476925",
            "minimum_receive_amount": "8586380381512155",
            "approval_spender": "0x1b6257cae4192e62b629efca21771be3d759183d",
            "approval_amount": "20000000"
          },
          "validation_status": "validated",
          "date_expire": "2026-11-02T15:50:44Z"
        }
        """#,
        "confirm_v3_prepare_usdttron_ton": #"""
        {
          "route_id": "fd660925-fa3a-4787-ad74-285f14577ecd",
          "provider_route_id": "0xed680e8961a8c201c09b35f96ed6ce98aeeefae11abc160beefad33ffc495b84",
          "aggregator": "swapsxyz",
          "execution_id": "647175d6-aa5c-4898-83eb-3066721fa1c4",
          "operation": {
            "id": "fd660925-fa3a-4787-ad74-285f14577ecd",
            "payloads": [
              {
                "id": "e317aa67-5a31-4a20-91a6-cf6099a5fb12",
                "type": "main",
                "chain_id": "tron/mainnet",
                "version": 1,
                "meta": {
                  "to": "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
                  "value": "0",
                  "data": "a9059cbb0000000000000000000000000ecb1ebffb8ba97e2985cbda3cbd7ec88352718e0000000000000000000000000000000000000000000000000000000001312d00"
                }
              }
            ]
          },
          "human_summary": {
            "action": "Swap USDT for GRAM",
            "spend_asset": "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
            "spend_amount": "20000000",
            "receive_asset": "ton/mainnet/coin",
            "receive_amount": "12193496400",
            "minimum_receive_amount": "12071561436",
            "protocol": "alt-vm-1"
          },
          "validation_status": "validated",
          "date_expire": "2026-11-02T15:50:42Z"
        }
        """#,
        "confirm_v3_quote_btc_eth": #"""
        {
          "quote_id": "2e1a6363-6082-455d-970f-72fa5b56a266",
          "routes": [
            {
              "route_id": "73da9a8c-5d26-4002-9298-d8d61349c301",
              "provider_route_id": "e7fa4947-b933-4ca0-8ea5-2a9cfb0f8508",
              "aggregator": "swapsxyz",
              "route_type": "cross_chain_swap",
              "source_amount": "100000",
              "estimated_destination_amount": "33346700000000000",
              "minimum_destination_amount": "33013233000000000",
              "estimated_time": {
                "inbound_seconds": 0,
                "swap_seconds": 0,
                "outbound_seconds": 0,
                "total_seconds": 25
              },
              "total_slippage_bps": 100,
              "price_impact_bps": 115,
              "source_usd_price": 77840,
              "destination_usd_price": 2289.08,
              "fees": [
                {
                  "type": "protocol",
                  "asset": "btc/mainnet/coin",
                  "chain_id": "btc/mainnet",
                  "amount": "100",
                  "amount_usd": "0.08"
                },
                {
                  "type": "application",
                  "asset": "btc/mainnet/coin",
                  "chain_id": "btc/mainnet",
                  "amount": "700",
                  "amount_usd": "0.54"
                }
              ],
              "legs": [],
              "date_expire": "2026-11-02T15:50:32Z",
              "risk_level": "medium"
            }
          ]
        }
        """#,
        "confirm_v3_quote_ton_usdt": #"""
        {
          "quote_id": "e2b7889c-a751-4b7c-a940-b9a2a7fef6a0",
          "routes": [
            {
              "route_id": "036bb244-764a-4cb0-b5b8-8e1362551794",
              "provider_route_id": "ecb2e9d79c939c00629d8bbdd1a75fcea4214c93c870a93264b2472b89405b3c",
              "aggregator": "omniston",
              "protocol": "omniston",
              "route_type": "same_chain_swap",
              "source_amount": "1000000000",
              "estimated_destination_amount": "1183456",
              "minimum_destination_amount": "1171621",
              "total_slippage_bps": 100,
              "price_impact_bps": 1,
              "source_usd_price": 1.1956847467785436,
              "destination_usd_price": 0.9989012086704624,
              "fees": [
                {
                  "type": "gas",
                  "asset": "ton/mainnet/coin",
                  "amount": "40000000",
                  "amount_usd": "0.047827"
                },
                {
                  "type": "integrator",
                  "asset": "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe",
                  "amount": "8342",
                  "amount_usd": "0.008333"
                }
              ],
              "legs": [],
              "date_expire": "2026-11-02T15:50:28Z",
              "risk_level": "low"
            }
          ]
        }
        """#,
        "confirm_v3_quote_usdteth_eth": #"""
        {
          "quote_id": "469fee52-4837-471a-9223-db6b7b6026ba",
          "routes": [
            {
              "route_id": "9462c7d9-637c-460e-8a36-a883c00b6f40",
              "provider_route_id": "7051aec3-70bf-4e09-903b-8c00c4094baa",
              "aggregator": "swapsxyz",
              "route_type": "same_chain_swap",
              "source_amount": "20000000",
              "estimated_destination_amount": "8678161447483770",
              "minimum_destination_amount": "8591379833008932",
              "total_slippage_bps": 100,
              "source_usd_price": 0.998937,
              "destination_usd_price": 2289.08,
              "tags": [
                "recommended"
              ],
              "fees": [
                {
                  "type": "protocol",
                  "asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "chain_id": "eth/mainnet",
                  "amount": "20000",
                  "amount_usd": "0.02"
                },
                {
                  "type": "application",
                  "asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "chain_id": "eth/mainnet",
                  "amount": "140000",
                  "amount_usd": "0.14"
                }
              ],
              "legs": [],
              "date_expire": "2026-11-02T15:50:31Z",
              "risk_level": "medium"
            },
            {
              "route_id": "4a3f8fb1-0c24-46da-838e-410f29509202",
              "provider_route_id": "9de4b81f-3686-4dcd-be35-c0a580966cf1",
              "aggregator": "swapkit",
              "protocol": "1inch",
              "route_type": "same_chain_swap",
              "source_amount": "20000000",
              "estimated_destination_amount": "8661502944501240",
              "minimum_destination_amount": "8574887915056228",
              "estimated_time": {
                "inbound_seconds": 13,
                "swap_seconds": 0,
                "outbound_seconds": 0,
                "total_seconds": 13
              },
              "total_slippage_bps": -80,
              "source_usd_price": 0.99894,
              "destination_usd_price": 2288.13,
              "tags": [
                "fastest"
              ],
              "warnings": [
                "insufficient_native_balance"
              ],
              "fees": [
                {
                  "type": "affiliate",
                  "asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "chain_id": "eth/mainnet",
                  "amount": "140000",
                  "amount_usd": "0.139846"
                },
                {
                  "type": "service",
                  "asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "chain_id": "eth/mainnet",
                  "amount": "30000",
                  "amount_usd": "0.029967"
                },
                {
                  "type": "liquidity",
                  "asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "chain_id": "eth/mainnet",
                  "amount": "5949",
                  "amount_usd": "0.005942"
                },
                {
                  "type": "inbound",
                  "asset": "eth/mainnet/coin",
                  "chain_id": "eth/mainnet",
                  "amount": "41949986767550",
                  "amount_usd": "0.095954"
                }
              ],
              "legs": [
                {
                  "leg_index": 0,
                  "type": "swap",
                  "chain_id": "eth/mainnet",
                  "chain_family": "EVM",
                  "from_asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "to_asset": "eth/mainnet/coin",
                  "protocol": "1inch"
                }
              ],
              "date_expire": "2026-11-02T16:49:32Z",
              "risk_level": "medium"
            },
            {
              "route_id": "3279a9e2-aaad-4832-a153-2638bfeb8803",
              "provider_route_id": "754536dc-1911-47a9-98ba-6e6323c4c005",
              "aggregator": "swapkit",
              "protocol": "chainflip",
              "route_type": "same_chain_swap",
              "source_amount": "20000000",
              "estimated_destination_amount": "8337406423924903",
              "minimum_destination_amount": "8254032359685654",
              "estimated_time": {
                "inbound_seconds": 13,
                "swap_seconds": 48,
                "outbound_seconds": 96,
                "total_seconds": 157
              },
              "total_slippage_bps": -451,
              "value_difference_bps": -451,
              "source_usd_price": 0.99894,
              "destination_usd_price": 2288.13,
              "warnings": [
                "insufficient_native_balance"
              ],
              "fees": [
                {
                  "type": "inbound",
                  "asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "amount": "161616",
                  "amount_usd": "0.161438"
                },
                {
                  "type": "liquidity",
                  "asset": "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                  "amount": "500000",
                  "amount_usd": "0.499836"
                },
                {
                  "type": "affiliate",
                  "asset": "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                  "amount": "135368",
                  "amount_usd": "0.135324"
                },
                {
                  "type": "service",
                  "asset": "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                  "amount": "29008",
                  "amount_usd": "0.028998"
                },
                {
                  "type": "outbound",
                  "asset": "eth/mainnet/coin",
                  "amount": "61444058130000",
                  "amount_usd": "0.140543"
                },
                {
                  "type": "inbound",
                  "asset": "eth/mainnet/coin",
                  "chain_id": "eth/mainnet",
                  "amount": "21568116590000",
                  "amount_usd": "0.049334"
                }
              ],
              "legs": [
                {
                  "leg_index": 0,
                  "type": "swap",
                  "chain_id": "eth/mainnet",
                  "chain_family": "EVM",
                  "from_asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "to_asset": "eth/mainnet/coin",
                  "protocol": "chainflip"
                }
              ],
              "date_expire": "2026-11-02T16:49:32Z",
              "risk_level": "medium"
            },
            {
              "route_id": "f5a848a2-59b2-47bc-a2e6-eed867ba9474",
              "provider_route_id": "6cfcbbfb-6eb9-4414-89f5-d60d39eab35a",
              "aggregator": "swapkit",
              "protocol": "flashnet",
              "route_type": "same_chain_swap",
              "source_amount": "20000000",
              "estimated_destination_amount": "8267594413379042",
              "minimum_destination_amount": "8184918469245252",
              "estimated_time": {
                "inbound_seconds": 13,
                "swap_seconds": 30,
                "outbound_seconds": 13,
                "total_seconds": 55
              },
              "total_slippage_bps": -531,
              "value_difference_bps": -531,
              "source_usd_price": 0.99894,
              "destination_usd_price": 2288.13,
              "warnings": [
                "insufficient_native_balance"
              ],
              "fees": [
                {
                  "type": "liquidity",
                  "asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "chain_id": "eth/mainnet",
                  "amount": "10000",
                  "amount_usd": "0.009989"
                },
                {
                  "type": "affiliate",
                  "asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "chain_id": "eth/mainnet",
                  "amount": "139930",
                  "amount_usd": "0.139776"
                },
                {
                  "type": "service",
                  "asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "chain_id": "eth/mainnet",
                  "amount": "29985",
                  "amount_usd": "0.029952"
                },
                {
                  "type": "inbound",
                  "asset": "eth/mainnet/coin",
                  "chain_id": "eth/mainnet",
                  "amount": "21568116590000",
                  "amount_usd": "0.049334"
                }
              ],
              "legs": [
                {
                  "leg_index": 0,
                  "type": "swap",
                  "chain_id": "eth/mainnet",
                  "chain_family": "EVM",
                  "from_asset": "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                  "to_asset": "eth/mainnet/coin",
                  "protocol": "flashnet"
                }
              ],
              "date_expire": "2026-11-02T16:04:32Z",
              "risk_level": "medium"
            }
          ],
          "provider_errors": [
            {
              "aggregator": "swapkit",
              "protocol": "chainflip_streaming",
              "code": "min_amount_not_met",
              "message": "sellAssetAmountTooSmall: Sell asset amount too small for provider CHAINFLIP_STREAMING."
            },
            {
              "aggregator": "swapkit",
              "protocol": "harbor",
              "code": "provider_error",
              "message": "insufficientLiquidity: Insufficient liquidity for trade"
            },
            {
              "aggregator": "swapkit",
              "protocol": "mayachain_streaming",
              "code": "provider_error",
              "message": "swapHalted: swap is halted"
            },
            {
              "aggregator": "swapkit",
              "protocol": "dex_other",
              "code": "no_route",
              "message": "noRoutesFound: No routes found for ETH.USDT-0xdAC17F958D2ee523a2206206994597C13D831ec7 -> ETH.ETH"
            }
          ]
        }
        """#,
        "confirm_v3_quote_usdttron_ton": #"""
        {
          "quote_id": "f8bb8b3c-ff09-4251-81ae-def86b6d343a",
          "routes": [
            {
              "route_id": "fd660925-fa3a-4787-ad74-285f14577ecd",
              "provider_route_id": "4d21e2ad-68cd-44b0-a3f5-3927b96c5fd8",
              "aggregator": "swapsxyz",
              "protocol": "alt-vm-1",
              "route_type": "cross_chain_swap",
              "source_amount": "20000000",
              "estimated_destination_amount": "12193496400",
              "minimum_destination_amount": "12071561436",
              "estimated_time": {
                "inbound_seconds": 0,
                "swap_seconds": 0,
                "outbound_seconds": 0,
                "total_seconds": 151
              },
              "total_slippage_bps": 100,
              "value_difference_bps": -2676,
              "source_usd_price": 0.9989190000000001,
              "destination_usd_price": 1.2,
              "fees": [
                {
                  "type": "bridge",
                  "asset": "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
                  "chain_id": "tron/mainnet",
                  "amount": "5212131",
                  "amount_usd": "5.21"
                },
                {
                  "type": "application",
                  "asset": "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
                  "chain_id": "tron/mainnet",
                  "amount": "140000",
                  "amount_usd": "0.14"
                }
              ],
              "legs": [
                {
                  "leg_index": 0,
                  "type": "bridge",
                  "chain_id": "tron/mainnet",
                  "chain_family": "TRON",
                  "from_asset": "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
                  "to_asset": "ton/mainnet/coin",
                  "protocol": "alt-vm-1"
                }
              ],
              "date_expire": "2026-11-02T15:50:31Z",
              "risk_level": "medium"
            }
          ]
        }
        """#,
    ]
}
