# RevealModule Documentation

## Overview

The **RevealModule** contract manages the process of revealing NFTs using Chainlink VRF for secure randomness. It works in tandem with a timelock controller to manage strategy updates for the reveal process and ensures that only approved NFT contracts can request reveals. The contract also integrates with a customizable reveal strategy via the `IRevealStrategy` interface.

---

## Table of Contents

- [Overview](#overview)
- [Architecture and Dependencies](#architecture-and-dependencies)
- [Key Components](#key-components)
  - [Data Structures](#data-structures)
  - [State Variables](#state-variables)
- [Core Functionalities](#core-functionalities)
  - [Reveal Process](#reveal-process)
  - [Strategy Management](#strategy-management)
  - [Administrative Functions](#administrative-functions)
- [Internal Functions](#internal-functions)
- [Security Considerations](#security-considerations)
- [Usage Examples](#usage-examples)
- [Events](#events)
- [Further Considerations](#further-considerations)

---

## Architecture and Dependencies

The contract leverages several external and internal components:
- **Chainlink VRF:**  
  - Inherits from `VRFConsumerBaseV2Plus` and uses `VRFV2PlusClient` for requesting randomness.
- **Timelock Controller:**  
  - Uses OpenZeppelin’s `TimelockController` to secure strategy update operations.
- **NFT Standard:**  
  - Interfaces with ERC721 tokens via `IERC721` for ownership checks during reveal requests.
- **Custom Interfaces and Libraries:**  
  - `IRevealStrategy` and `IRevealModule` for strategy execution and module functionality.
  - Custom error and event libraries (`Errors.sol` as `CustomErrors` and `Events.sol`) ensure standardized handling of errors and logs.

---

## Key Components

### Data Structures

- **RevealRequest Struct:**  
  Packs the NFT contract address (20 bytes) and token ID (12 bytes as `uint96`) into one 32-byte slot to save storage.
  
  ```solidity
  struct RevealRequest {
      address nftContract;
      uint96 tokenId;
  }
  ```

- **RevealStatus Enum:**  
  Tracks the current status of an NFT reveal:
  - `NotRequested`
  - `RequestPending`
  - `Revealed`

---

### State Variables

- **VRF Parameters (Immutable):**  
  - `keyHash`: The key hash for the VRF.
  - `subscriptionId`: The Chainlink VRF subscription ID.
  - `numWords`: Number of random words requested.
  
- **Timelock and Reveal Strategy:**  
  - `timelock`: An instance of `TimelockController` used to protect strategy update operations.
  - `revealStrategy`: The current reveal strategy contract implementing `IRevealStrategy`.
  
- **VRF Request Configuration:**  
  - `requestConfirmations`: Number of confirmations required for a VRF request.
  - `callbackGasLimit`: Gas limit for the VRF callback.
  
- **Mappings:**  
  - `revealRequests`: Maps VRF request IDs to their associated `RevealRequest`.
  - `approvedNFTContracts`: Tracks which NFT contracts are approved for reveal requests.
  - `revealStatus`: Maps a unique NFT key (using the NFT address and tokenId) to its `RevealStatus`.

---

## Core Functionalities

### Reveal Process

1. **Initiating a Reveal:**  
   - **Function:** `reveal(address nftContract, uint256 tokenId)`  
   - **Checks:**  
     - Validates that the NFT contract is approved.
     - Ensures the caller is the owner of the NFT.
     - Confirms that no previous reveal request is pending or completed.
   - **Process:**  
     - Requests randomness from Chainlink VRF.
     - Stores the reveal request using a packed struct.
     - Updates the NFT’s reveal status to `RequestPending`.
   - **Event:** Emits `RandomWordsRequestSent`.

2. **Randomness Fulfillment:**  
   - **Function:** `fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords)`  
   - **Process:**  
     - Retrieves the associated `RevealRequest`.
     - Calls the reveal strategy’s `reveal` function using the random word provided.
     - Based on the result, marks the NFT as `Revealed` or resets the status to allow a reattempt.
     - Cleans up the stored reveal request.
   - **Events:** Emits `RevealSuccessful` or `RevealFailed`.

---

### Strategy Management

- **Scheduling a Strategy Update:**  
  - **Function:** `scheduleStrategyUpdate(address newStrategy)`  
  - Uses the timelock to schedule an update of the reveal strategy. It encodes the call data and schedules the operation, emitting a `StrategyUpdateScheduled` event.

- **Executing a Strategy Update:**  
  - **Function:** `executeStrategyUpdate(address newStrategy)`  
  - Callable only by the timelock, this function updates the `revealStrategy` to the new address and emits `StrategyUpdated`.

- **Cancelling a Scheduled Update:**  
  - **Function:** `cancelStrategyUpdate(address newStrategy)`  
  - Cancels a previously scheduled strategy update and emits `StrategyUpdateCancelled`.

---

### Administrative Functions

- **Approving NFT Contracts:**  
  - **Function:** `setNFTContractApproval(address nftContract, bool approved)`  
  - Allows the owner to mark NFT contracts as approved or revoke their approval.

- **Updating VRF Configuration:**  
  - **Functions:**  
    - `updateCallbackGasLimit(uint32 _callbackGasLimit)`
    - `updateRequestConfirmations(uint16 _requestConfirmations)`  
  - Permit the owner to adjust VRF parameters, emitting respective events upon updates.

---

## Internal Functions

- **_validateRevealRequest:**  
  Validates the reveal request by ensuring:
  - The NFT contract is not the zero address.
  - The caller owns the token.
  - The NFT contract is approved.
  - A reveal strategy is set.
  - The NFT hasn’t already been revealed or is pending a reveal.
  
- **_getNFTKey:**  
  Generates a unique key for an NFT by hashing its contract address and token ID. This key is used to manage the reveal status in mappings.

---

## Security Considerations

- **Timelock Governance:**  
  The use of a timelock controller secures strategy updates, ensuring that changes are scheduled and cannot be executed immediately.
  
- **Ownership and Approval Checks:**  
  The contract validates that the NFT owner is the one making the reveal request and that the NFT contract is approved for reveal operations.
  
- **Chainlink VRF Integration:**  
  Randomness is sourced via Chainlink VRF, which helps prevent manipulation in the reveal process.
  
- **Error Handling:**  
  Custom errors from `CustomErrors` provide clear and gas-efficient failure messages.

---

## Usage Examples

### Approving an NFT Contract

```solidity
// Owner approves an NFT contract for reveal requests
revealModule.setNFTContractApproval(nftContractAddress, true);
```

### Requesting a Reveal

```solidity
// NFT owner requests a reveal for their token
revealModule.reveal(nftContractAddress, tokenId);
```

### Scheduling a Strategy Update

```solidity
// Owner schedules a new reveal strategy update via the timelock
revealModule.scheduleStrategyUpdate(newStrategyAddress);
```

### Updating VRF Parameters

```solidity
// Owner updates the callback gas limit for VRF requests
revealModule.updateCallbackGasLimit(newGasLimit);
```

---

## Events

The contract emits several events to track key actions:
- **RandomWordsRequestSent:** Emitted when a reveal request is initiated.
- **RevealSuccessful:** Emitted upon successful NFT reveal.
- **RevealFailed:** Emitted if the reveal process fails.
- **StrategyUpdateScheduled, StrategyUpdated, StrategyUpdateCancelled:** Emitted during the strategy update lifecycle.
- **NFTContractApprovalChanged:** Emitted when an NFT contract’s approval status changes.
- **CallbackGasLimitUpdated, RequestConfirmationsUpdated:** Emitted when VRF configuration parameters are updated.

---
