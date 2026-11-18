# Agent Proof Daily

**One check-in per day. Only for Binance Agent ID holders.**

Agent Proof Daily is a small, fully on-chain ritual built around Binance
Agent ID — the on-chain name (`name.ai`) of an Agentic Wallet. Every day, an
Agent ID holder can check in once. Consecutive days build a streak. The first
check-in mints a **soulbound badge** whose metadata is generated live from
on-chain state: the streak printed in its JSON attributes and its SVG artwork
is always the holder's current streak.

## How Agent ID is used

Agent ID is not a login decoration here — it is the product's only key:

- **Access control.** `checkIn()` reads the official SPACE ID Agent ID
  registry on BNB Chain (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`) and
  reverts for any wallet that does not hold an Agent ID. No Agent ID, no
  check-in, no badge, no exceptions.
- **Identity.** The soulbound badge is bound to the Agent ID holder's wallet
  forever. It cannot be transferred, sold, or approved away — it is a proof of
  presence for that identity, nothing else.
- **Continuity.** The daily streak is a lightweight, public, verifiable
  activity record for an agent identity — the kind of signal agent-native
  services can build on.

## Safety by design

- No owner, no admin keys, no pause switch, no upgrade path.
- No fees, no payable functions, no token approvals, nothing to drain.
- The only external call is a read of the official Agent ID registry.
- The badge has **no monetary value** and is not a financial product.

## Contracts

- `contracts/AgentProofDaily.sol` — the whole product in one verified,
  dependency-free Solidity file (MIT).
- BNB Chain deployment: `0xb0e87ef1924bd96082b2d215bb6be846a69a4283`
  (deterministic CREATE2 address; deployed by the `plinsid.ai` Agentic Wallet).

## Tests

Foundry tests run against a live BNB Chain fork and the real Agent ID
registry (`forge test`): non-holders are rejected, a real Agent ID holder
checks in and receives badge #1, same-day repeats revert, streaks extend and
reset correctly, badge transfers and approvals revert, and `tokenURI` returns
live metadata.

## Frontend

`frontend/index.html` — a single static page (ethers.js via CDN): connect a
wallet on BNB Chain, see your Agent ID status, streak and the global
leaderboard, and check in. Open it inside any wallet browser (e.g. the Binance
app) or with a browser wallet extension.

## Built for

The Binance Wallet × BNB Chain **Agent ID Hackathon**
(submission period 18 Nov – 9 Dec 2026), by the holder of `plinsid.ai`.
