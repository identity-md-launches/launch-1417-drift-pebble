// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Drift Pebble (DPBL)
/// @notice A fixed-supply ERC-20 with 18 decimals and ordinary, fee-free transfers.
/// @dev The immediate deployer receives all tokens. During the custom launch this is the factory.
contract DriftPebble is ERC20 {
    /// @notice One billion tokens expressed in the token's smallest units (10^27).
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    /// @notice Mints the entire supply once; no subsequent mint or burn entry point exists.
    constructor() ERC20("Drift Pebble", "DPBL") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
