# Evidence — Agent ID contract on BSC mainnet

Checked live on 2026-11-23 via `cast` against
`https://bsc-dataseed.binance.org` (Foundry 1.10.0).

Target: `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`
(the address published in the Binance Agent ID Hackathon announcement).

| Check | Result |
|---|---|
| `name()` | `"SPACE ID Agent ID"` |
| `symbol()` | `"AI"` |
| `supportsInterface(0x80ac58cd)` (ERC-721) | `true` |
| `balanceOf(0x000…dEaD)` (non-holder) | `0` |
| `balanceOf(address(0))` | reverts `ERC721InvalidOwner(0x0)` — standard ERC-721 behaviour; `BIPAgentIDGate.hasAgentID` short-circuits the zero address |
| `totalSupply()` | reverts (not ERC-721Enumerable) — the gate does not use it |
| Deployed code size | ≈ 17.5 KB (non-empty, contract is live) |

Conclusion: the address is the live SPACE ID Agent ID ERC-721 contract and
`balanceOf(address) > 0` is a working ownership check, as prescribed by the
hackathon rules. `BIPAgentIDGate` integrates against exactly this interface
(`contracts/interfaces/IAgentID.sol`).
