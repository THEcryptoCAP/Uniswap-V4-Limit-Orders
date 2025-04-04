// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

//The goal for us is that we create a generic Hook that can be attached to any pool on Uniswap v4. This hook must allow users to place (and cancel) take-profit orders on-chain.
// Then, at some point in time, if it is possible for that take-profit order to be fulfilled because the price has moved enough to make that happen.
// we should fill that order and the user should then be able to claim the swapped tokens out into their own wallet.

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

contract TakeProfitsHook is BaseHook, ERC1155 {
    // Use the PoolIdLibrary for PoolKey to add the `.toId()` function on a PoolKey
    // which hashes the PoolKey struct into a bytes32 value
    using PoolIdLibrary for PoolKey;

    // Create a mapping to store the last known tickLower value for a given Pool
    mapping(PoolId poolId => int24 tickLower) public tickLowerLasts;

    // Create a nested mapping to store the take-profit orders placed by users
    // The mapping is PoolId => tickLower => zeroForOne => amount
    // PoolId => (...) specifies the ID of the pool the order is for
    // tickLower => (...) specifies the tickLower value of the order i.e. sell when price is greater than or equal to this tick
    // zeroForOne => (...) specifies whether the order is swapping Token 0 for Token 1 (true), or vice versa (false)
    // amount specifies the amount of the token being sold
    mapping(PoolId poolId => mapping(int24 tick => mapping(bool zeroForOne => int256 amount))) public takeProfitPositions;

    // initializing Basehook and ERC1155 parent contracts in the constructor 
     constructor(
        IPoolManager _poolManager,
        string memory _uri
    ) BaseHook(_poolManager) ERC1155(_uri) {}


    // the logical workflow is as follows 
    // 1. A user creates a take-profit order through a placeOrder(…) function in our hook
    // 2. Our Hook, which is also an ERC-1155 contract, will mint ERC-1155 tokens to the user's wallet representing their order. 
    //    These tokens act kind of as a receipt - so if their order does get fulfilled in the future, they can return these receipt tokens back to the hook to withdraw their swapped tokens out.
    // 3. We hook into the afterSwap function - and every time any trader makes a swap, we check the new price of the tokens and execute
    //    any take-profit orders in the afterSwap function through the pool by market-selling those tokens given the new price
    // 4. Users who created those orders can then come back and exchange their ERC-1155 tokens for the swapped tokens.


    // Required override function for BaseHook to let the 
    // poolmanager know which hooks are implemented
     function getHookPermissions()
     public
     pure
     override
     returns (Hooks.Permissions memory)
     {
        return Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: true,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
         //So, critically, all the magic is in the afterSwap hook. Since each swap that takes place in the pool affects the price in one direction or another, it's a great place to look for any pending orders that can possibly be filled now - and if so, filling them.
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false
        });
     }
    
    // Utility Helpers
    function _setTickLowerLast(PoolId poolId, int24 tickLower) private {
    tickLowerLasts[poolId] = tickLower;
    }

    function _getTickLower(int24 actualTick, int24 tickSpacing) private pure returns (int24) {
    int24 intervals = actualTick / tickSpacing;
    if (actualTick < 0 && actualTick % tickSpacing != 0) intervals--; // round towards negative infinity
    return intervals * tickSpacing;
    } // explain this functionnnn 
}

   
