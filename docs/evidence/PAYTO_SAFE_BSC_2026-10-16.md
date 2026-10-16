# payTo Safe verification — 2026-10-16

**payTo (locked):** `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`  
**Network:** BSC mainnet (chain ID 56)  
**RPC:** `https://bsc-dataseed.binance.org`  
**Block:** ~127884052  
**UTC:** 2026-10-16T00:39:56Z

## On-chain checks

| Check | Result |
|-------|--------|
| `eth_getCode` | Present (~123 byte proxy) |
| `VERSION()` | `1.5.0` |
| `getThreshold()` | `2` |
| `getOwners()` length | `2` |
| Owner 1 | `0xfCeAfeC082F9e8b17CDb51f33c3d5c9759A25E03` |
| Owner 2 | `0x6783714167eC1c3519455AfCf2c93f6074624575` |
| Native BNB | 0 |
| USDT balance | 0 |

## Policy mapping

- Product requirement: multisig `payTo` → **satisfied** (Safe 1.5.0, 2-of-2).
- Interim EOA `0x6783…4575` is an **owner**, not the payment receiver.
- Config: `BIP_PAY_TO=0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`

## Explorer

https://bscscan.com/address/0xFf265912c76342c8469cE18aB9DF0B2f37d9373c

## Notes

Read-only verification. No funds moved. Production payment enablement still blocked by remaining audit gates and B402 integration.
