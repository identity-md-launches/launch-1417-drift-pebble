# Drift Pebble (DPBL)

Drift Pebble is an immutable, fee-free ERC-20. Its constructor mints exactly
**1,000,000,000 DPBL with 18 decimals** to the immediate deployer (`msg.sender`).
The total supply in smallest units is **1000000000000000000000000000** (`10^27`).

## Contract and assumptions

The production contract is `src/DriftPebble.sol:DriftPebble`. It inherits the
vendored OpenZeppelin Contracts v5.4.0 ERC-20 without overriding transfer or
approval behavior. Its only customization is the name, symbol, supply constant,
and constructor mint.

- No constructor arguments, initialization call, owner, administrator, or external
  address configuration is needed. The constructor makes no external calls.
- Supply is fixed. No external mint, burn, pause, blacklist, seizure, upgrade,
  permit, tax, reflection, or transfer-limit functions are provided.
- Transfers deliver their entire amount. Successful `transfer`, `approve`, and
  `transferFrom` calls return `true`; invalid operations revert with standard
  ERC-6093 errors.
- Zero-amount and self-transfers are supported. Transfers to the zero address
  revert, even for zero amounts. Approvals to the zero address also revert.
- Finite allowances decrease on `transferFrom`. An allowance of `uint256.max`
  remains unchanged until the holder replaces or revokes it. `approve` replaces
  the existing allowance; it does not add to it.
- Construction and transfers emit `Transfer`; explicit approvals emit `Approval`.
  OpenZeppelin does not emit an additional `Approval` when spending an allowance.
- Transfers do not call recipients. This contract uses no oracle, randomness,
  timestamps, block-number logic, bridging, proxy, or external linked library.

## Reproducible local build and tests

Run from the repository root with Foundry and Solidity **0.8.26** installed:

```sh
forge build
forge test
forge fmt --check
```

`foundry.toml` pins solc 0.8.26, the Paris EVM target, optimization at 200 runs,
and `bytecode_hash = "none"`. Paris avoids reliance on newer EVM opcodes.
The build grants no FFI or filesystem permissions. All Solidity dependencies and
their licenses are ordinary vendored files; see [DEPENDENCIES.md](DEPENDENCIES.md)
for exact versions, download origins, and archive checksums. An offline machine
needs only Foundry and the pinned compiler, with no dependency installation.

The suite covers metadata, a single constructor mint event, factory CREATE2
deployment and immediate-deployer ownership, transfers, approvals, revocation,
allowance isolation, insufficient balances/allowances, zero-address rejection,
atomic rollback, self/zero transfers, exact launch custody transfers, unavailable
privileged entry points, and forbidden runtime opcodes. Four parameterized tests
run 512 cases each. Two stateful invariants run 128 sequences at depth 64 over
transfers, approvals, and delegated transfers, checking balances, supply, and an
independent allowance model. Tests use only local actors and no environment,
network, forks, wallet keys, or shared persistent state.

The local custody-flow test models factory distribution, claims, and token
movement into and out of pool custody. It does not execute a Uniswap swap. The
provided protected test is a separate launch integration harness requiring its
own factory libraries, v4 PoolManager, and resolved manifest. That harness is an
input to the independent verifier, not part of this project's local test suite.

## Deployment parameters and handoff

| Parameter | Value |
| --- | --- |
| Solidity contract identifier | `DriftPebble` |
| Artifact | `out/DriftPebble.sol/DriftPebble.json` |
| Constructor arguments | None (`[]`) |
| Constructor transaction value | `0` native currency |
| Name / symbol / decimals | `Drift Pebble` / `DPBL` / `18` |
| Total supply, smallest units | `1000000000000000000000000000` |
| Initial holder | The address executing CREATE or CREATE2 |
| Target chain from the assignment | Robinhood Chain, chain ID `4663` |

For the custom launch, the launch factory must deploy the token directly from the
built creation bytecode. **The factory receives the entire supply**, rather than
the requesting wallet, transaction origin, or a helper. A separate deployment
helper would itself receive all tokens, so do not interpose one. The test factory
under `test/` exists only to verify this behavior and is not a deployment artifact
to include in the launch.

The assignment supplies the following launch policy to the later manifest and
factory steps. These values are not constructor inputs and are not hardcoded into
token transfer logic:

| Launch setting | Assignment value |
| --- | --- |
| Paired IMD token (18 decimals) | `0x5f7bb59365ce557c26dbcaa4ee9d39a4b95b7127` |
| Pool fee | `12500` (1.25%) |
| Tick spacing | `60` |
| Pool initial-price provenance value | `79228162514264337593543950336` |
| Economics | `{"poolBps":9000,"initialMarketCapWei":"2500000000000000000000"}` |

The factory handles the 10% swarm allocation (100,000,000 DPBL), the 90% pool
allocation (900,000,000 DPBL), and the opening price derived from the requested
2,500 IMD market cap. Pool rounding and settlement are the factory's concern;
the token charges no fee or deduction on any flow. This project allocates nothing
separately and deploys no application contracts. The later manifest step writes
`launch.json`; none is supplied here. No production deployment or transaction is
performed by this project.

## After launch

There are no owner-settable settings, privileged keys, keepers, or maintenance
transactions for this token. The launch operator is responsible for deploying the
exact reviewed artifact through the intended factory, checking chain and contract
addresses, resolving the manifest, running the full launch integration checks,
distributing the supply, and verifying source and compiler settings on the chain's
explorer. The constructor mint event should show the factory as recipient and the
full `10^27` units. Distribution should leave total supply unchanged.

Holders control their transfers and approvals. Applications should use the
18-decimal base-unit amount, verify the token address, request only needed
allowances, and query `allowance` rather than infer it solely from events. When
changing an existing allowance, revoking it first and waiting for confirmation
reduces the standard ERC-20 allowance replacement race. Unlimited approvals expose
the holder's available balance to the approved spender until revoked.

There is no recovery function for tokens sent to an unintended address, to this
token contract, or to a contract that cannot return them. Native-currency calls
are not accepted through a receive/fallback function, and forcibly sent native
currency cannot be recovered. Custody and transaction correctness remain the
holder's responsibility.

## Review scope

The production change is the small constructor-only specialization of the
vendored ERC-20. Local verification includes the Foundry unit, fuzz, and stateful
invariant suites and review of the inherited balance and allowance paths. Supply
changes are only reachable during construction; no recipient callback or external
call creates a reentrancy path, and no privileged caller can bypass allowances.
This work does not include Slither, Mythril, a live-chain deployment, a full v4
integration run, or an independent security audit. The independent launch review
and integration checks remain the launch operator's responsibility before release.
