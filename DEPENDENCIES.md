# Vendored dependencies

- `lib/openzeppelin-contracts`: [OpenZeppelin/openzeppelin-contracts v5.4.0](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v5.4.0)
  - Archive: https://codeload.github.com/OpenZeppelin/openzeppelin-contracts/tar.gz/refs/tags/v5.4.0
  - Archive SHA-256: `b89829be48bc501051002191733268a93ef6e238a4bb65d8fd1cbdf3969050d1`
  - 6 unmodified files copied; only the ERC-20 dependency closure and license.

- `lib/forge-std`: [foundry-rs/forge-std v1.9.7](https://github.com/foundry-rs/forge-std/tree/v1.9.7)
  - Archive: https://codeload.github.com/foundry-rs/forge-std/tar.gz/refs/tags/v1.9.7
  - Archive SHA-256: `45157353ab49eab01d294565866731e599b32401757229689ee459aa26b7ee94`
  - 30 unmodified files copied; the Solidity `src/` tree and both licenses.

All dependencies are ordinary source files, with their upstream licenses. No submodules, package manager, install step, or network access are needed to build or test. Foundry and the pinned Solidity compiler are the only external tooling prerequisites.
