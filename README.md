# NFT Reveal and Staking Contracts

## Overview

This repository contains the implementation of contracts for NFT reveal and staking functionality:

1. **[RevealModule](docs/RevealModuleDocumentation.md)**: Manages the NFT reveal process using Chainlink VRF.
2. **[InCollectionRevealStrategy](docs/InCollectionRevealStrategyDocumentation.md)**: Reveals NFTs within the same collection.
3. **[SeparateCollectionRevealStrategy](docs/SeparateCollectionRevealStrategy.md)**: Reveals NFTs by transferring them to a separate collection.
4. **[SPNFT](docs/SPNFTDocumentation.md)**: Represents the base NFT collection.
5. **[RevealedNFT](docs/RevealedNFTDocumentation.md)**: Represents the collection of revealed NFTs.
6. **[StakingContract](docs/StakingContractDocumentation.md)**: Allows users to stake NFTs and earn rewards.

Each contract has its associated documentation linked above to guide you through its functionality and usage.

## Foundry

We are using **Foundry** as our development toolkit for Ethereum applications. Foundry is a blazing fast, portable, and modular toolkit written in Rust, consisting of the following components:

- **Forge**: Ethereum testing framework (similar to Truffle, Hardhat, and DappTools).
- **Cast**: A versatile utility for interacting with EVM smart contracts, sending transactions, and retrieving chain data.
- **Anvil**: A local Ethereum node, similar to Ganache or Hardhat Network.
- **Chisel**: A fast, utilitarian, and verbose Solidity REPL.

For more information, refer to the [Foundry Documentation](https://book.getfoundry.sh/).

## Installation

To get started, install Foundry by running the following command:

```shell
curl -L https://foundry.paradigm.xyz | bash
```

After installation, initialize Foundry by running:

```shell
foundryup
```

This command will install the necessary tools, including `forge`, `cast`, and `anvil`.

For detailed instructions, visit the [Foundry Installation Guide](https://book.getfoundry.sh/getting-started/installation).

## Usage

### Build the Contracts

Compile the smart contracts in your project:

```shell
$ forge build
```

### Test the Contracts

Run the test cases for your contracts with optional fuzz testing:

```shell
$ forge test --fuzz-runs 10
```

### Format the Code

Automatically format your Solidity code:

```shell
$ forge fmt
```

### Generate Gas Snapshots

Generate gas reports for the functions in your contracts:

```shell
$ forge snapshot
```

### Run Anvil

Run a local Ethereum node for testing and development:

```shell
$ anvil
```

### Cast

Interact with the Ethereum blockchain using `cast`:

```shell
$ cast <subcommand>
```

### Help

To get help and see all available commands for Foundry, Anvil, or Cast:

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Documentation Links

- **[Core Architecture](docs/CoreArchitecture.md)**: Overview of the architecture and flow of the NFT reveal process.
- **[RevealModule Documentation](docs/RevealModuleDocumentation.md)**: Details about the NFT reveal module.
- **[InCollectionRevealStrategy Documentation](docs/InCollectionRevealStrategyDocumentation.md)**: Details about the in-collection reveal strategy.
- **[SeparateCollectionRevealStrategy Documentation](docs/SeparateCollectionRevealStrategyDocumentation.md)**: Details about the separate collection reveal strategy.
- **[SPNFT Documentation](docs/SPNFTDocumentation.md)**: Details about the base NFT collection.
- **[RevealedNFT Documentation](docs/RevealedNFTDocumentation.md)**: Details about the revealed NFT collection.
- **[StakingContract Documentation](docs/StakingContractDocumentation.md)**: Details about the staking contract.
- **[MetadataGenerator Documentation](docs/MetadataGeneratorDocumentation.md)**: Details about the metadata generation library.
