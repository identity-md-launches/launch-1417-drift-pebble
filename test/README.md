# Drift Pebble tests

Run `forge build` and `forge test` from the repository root. The tests use the
existing vendored dependencies and Solidity 0.8.26; they require no network,
fork, environment variables, FFI, or production addresses.

The original deployment, metadata, events, launch custody, and ERC-20 tests in
`DriftPebble.t.sol` are retained. Administrative call probes now encode valid
arguments so rejection cannot be attributed to malformed calldata.

`DriftPebble.edge.t.sol` adds explicit one-unit, full-supply, maximum-integer,
and maximum-minus-one allowance cases. It covers address-role overlap, caller
versus transaction-origin authority, zero-address rejection, approval before
funding, and allowance isolation. Its properties check transfer round trips,
split versus combined transfers, recovery after an insufficient-balance failure,
and replacement of unlimited approval with a finite limit. Both fuzz suites
set 1,000 runs in inline configuration.

## Stateful properties

`DriftPebble.invariant.t.sol` runs 256 sequences of 128 calls with four actors.
Only the handler's eleven listed action selectors are targeted. Successful
transfers, approvals, full-balance moves, and delegated spending interleave with
revocations, overspending, and invalid-recipient/spender attempts. Dedicated
funded-owner actions ensure nonzero delegated spending is reachable without
waiting for random approvals and balances to coincide.

The following properties are checked after each action:

- The sum of all tracked balances and `totalSupply()` both equal the specified
  `1_000_000_000 * 10**18` units.
- Each actor's balance equals the handler's independent accounting. No successful
  transfer leaves the closed actor set; the zero address, token, and handler
  remain unfunded.
- Every owner/spender allowance equals the model, including finite consumption,
  unlimited approvals, overwrites, and revocations. Zero-address allowances stay
  zero.
- Metadata and the declared initial supply remain fixed.

Rejected operations expect specific ERC-20 errors. They make no changes to the
model, so the next invariant check also verifies rollback of balances and
allowances. Expected errors are consumed inside the handler; unexpected handler
reverts fail the campaign. After each sequence, all actors transfer their full
remaining balances to the initial holder, checking continued transfer liveness
and recovery of the entire supply.

The closed actor model tests token accounting, not arbitrary application behavior.
The existing custody-flow test does not execute a Uniswap swap. The supplied
protected launch harness needs its separate factory/v4 sources and resolved
launch environment and is run by the independent verifier.
