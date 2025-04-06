# Uniswap-V4-Limit-Orders
in this repo i am understanding more about uniswap v4 , hooks, how to ideate, take profits and moreee.
# Uniswap v4 Take-Profit Limit Order Hook

## Overview

This repository contains a Uniswap v4 Hook implementation that enables take-profit limit orders on any Uniswap v4 pool. The `TakeProfitsHook` contract allows users to place limit orders that automatically execute when the price reaches a specified level, without requiring any additional user interaction after the initial order placement.

## Technical Architecture

The `TakeProfitsHook` is built on Uniswap v4's Hook system and implements the ERC-1155 token standard to represent limit orders. This implementation leverages Uniswap v4's new hook architecture to enable functionality that wasn't possible in previous versions.

### Key Components

1. **BaseHook Integration**: Extends the `BaseHook` contract from v4-periphery to interact with the Uniswap v4 `PoolManager`.
2. **ERC-1155 Token Standard**: Implements the ERC-1155 standard to represent limit orders as tokens, allowing for transferability and partial order execution.
3. **Take-Profit Order System**: Provides a mechanism for users to place, cancel, and redeem take-profit orders.

## Core Functionality

### Order Lifecycle

1. **Order Placement**: Users place take-profit orders by specifying a price (tick) at which they want to sell their tokens.
2. **Order Tracking**: The contract mints ERC-1155 tokens to the user as receipts for their orders.
3. **Order Execution**: When the market price reaches the specified level, the hook automatically executes the order.
4. **Token Redemption**: Users can redeem their ERC-1155 tokens to claim the swapped tokens after their orders are executed.

## Key Functions

### Order Management

#### `placeOrder`
```solidity
function placeOrder(
    PoolKey calldata key,
    int24 tick,
    uint256 amountIn,
    bool zeroForOne
) external returns (int24)
```

Places a take-profit order for a specific pool at a given tick (price). The function:
- Calculates the correct tick boundary
- Updates the take-profit position mapping
- Mints ERC-1155 tokens to the user
- Transfers the tokens to be sold from the user to the contract

Parameters:
- `key`: The Uniswap v4 pool key
- `tick`: The price level at which to execute the order
- `amountIn`: The amount of tokens to sell
- `zeroForOne`: Direction of the swap (true = sell token0 for token1, false = sell token1 for token0)

#### `cancelOrder`
```solidity
function cancelOrder(
    PoolKey calldata key,
    int24 tick,
    bool zeroForOne
) external
```

Cancels an existing take-profit order. The function:
- Burns the user's ERC-1155 tokens
- Updates the take-profit position mapping
- Returns the original tokens to the user

#### `redeem`
```solidity
function redeem(
    uint256 tokenId,
    uint256 amountIn,
    address destination
) external
```

Allows users to claim their swapped tokens after an order has been executed. The function:
- Calculates the user's share of the executed order
- Burns the ERC-1155 tokens
- Transfers the swapped tokens to the specified destination

### Hook Implementation

#### `afterSwap`
```solidity
function afterSwap(
    address addr,
    PoolKey calldata key,
    IPoolManager.SwapParams calldata params,
    BalanceDelta,
    bytes calldata
) external override poolManagerOnly returns (bytes4)
```

This is the core function that executes take-profit orders when the price reaches the specified level. It's called after every swap in the pool and:
- Checks for re-entrancy to prevent attacks
- Attempts to fulfill any eligible orders
- Updates the last processed tick

#### `_tryFulfillingOrders`
```solidity
function _tryFulfillingOrders(
    PoolKey calldata key,
    IPoolManager.SwapParams calldata params
) internal returns (bool, int24)
```

Internal function that scans for and executes eligible take-profit orders. It:
- Determines the current tick after a swap
- Executes orders in the opposite direction of the swap
- Returns whether more orders might be available to fulfill

## Data Structures

### Key Mappings

1. **`takeProfitPositions`**: Stores the take-profit orders
   ```solidity
   mapping(PoolId poolId => mapping(int24 tick => mapping(bool zeroForOne => int256 amount)))
   ```

2. **`tokenIdExists`**: Tracks whether a token ID exists
   ```solidity
   mapping(uint256 tokenId => bool exists)
   ```

3. **`tokenIdClaimable`**: Tracks how many swapped tokens are claimable for a token ID
   ```solidity
   mapping(uint256 tokenId => uint256 claimable)
   ```

4. **`tokenIdTotalSupply`**: Tracks the total supply of tokens for a token ID
   ```solidity
   mapping(uint256 tokenId => uint256 supply)
   ```

5. **`tokenIdData`**: Stores the pool key, tick, and swap direction for a token ID
   ```solidity
   mapping(uint256 tokenId => TokenData)
   ```

### TokenData Struct

```solidity
struct TokenData {
   PoolKey poolKey;
   int24 tick;
   bool zeroForOne;
}
```

## Technical Implementation Details

### Token ID Generation

Token IDs are generated by hashing the pool ID, tick, and swap direction:
```solidity
function getTokenId(PoolKey calldata key, int24 tickLower, bool zeroForOne)
public pure returns(uint256) {
    return uint256(keccak256(abi.encodePacked(key.toId(), tickLower, zeroForOne)));
}
```

### Order Execution Logic

1. When a swap occurs in the pool, the `afterSwap` hook is triggered
2. The hook checks if the current tick has changed since the last swap
3. If the tick has changed, it looks for take-profit orders that can now be executed
4. For each eligible order, it executes a swap in the opposite direction
5. The swapped tokens are stored for later redemption by the order owner

### Re-entrancy Protection

The hook includes protection against re-entrancy attacks by checking if the caller is the hook itself:
```solidity
if (addr == address(this)) {
    return TakeProfitsHook.afterSwap.selector;
}
```

## Usage Example

1. A user places a take-profit order to sell 100 WETH for USDC when the price reaches a specific level
2. The hook mints ERC-1155 tokens to the user as a receipt for their order
3. When the market price reaches the specified level, the hook automatically executes the order
4. The user can then redeem their ERC-1155 tokens to claim the USDC

## Security Considerations

- The hook includes protection against re-entrancy attacks
- Orders are executed atomically to prevent partial execution
- The contract uses the ERC-1155 standard to ensure order ownership and transferability

## Conclusion

The `TakeProfitsHook` demonstrates the power of Uniswap v4's hook system by implementing functionality that wasn't possible in previous versions. By enabling take-profit limit orders, it enhances the trading experience on Uniswap and provides users with more sophisticated trading options.
