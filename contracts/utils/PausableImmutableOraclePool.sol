// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {OraclePool} from "./OraclePool.sol";

/**
 * @title PausableImmutableOraclePool Contract
 * @dev An OraclePool contract that is pausable and immutable.
 * The oracle and the fee cannot be changed after deployment.
 * The owner can pause and unpause the contract, which will prevent the `swap` and
 * `pull` functions from being called.
 */
contract PausableImmutableOraclePool is OraclePool, Pausable {
    error PausableImmutableOraclePoolImmutable();
    error PausableImmutableOraclePoolInvalidParameters();

    /**
     * @dev Sets the immutable values for {SENDER}, {TOKEN_IN}, {TOKEN_OUT} and the initial values for the oracle, the swap fee and the owner.
     *
     * The `SENDER` account is the only account allowed to call the swap and pull functions.
     * The `TOKEN_IN` and `TOKEN_OUT` addresses are the addresses of the tokens to be swapped.
     * The `oracle` address is the address of the oracle contract. It cannot be changed after deployment and therefore
     * cannot be set to the zero address.
     * The `fee` is the fee to be applied to each swap (in 1e18 scale). It cannot be changed after deployment.
     * The `initialOwner` is the address of the initial owner.
     */
    constructor(address sender, address tokenIn, address tokenOut, address oracle, uint96 fee, address initialOwner)
        OraclePool(sender, tokenIn, tokenOut, oracle, fee, initialOwner)
    {
        if (oracle == address(0)) revert PausableImmutableOraclePoolInvalidParameters();
    }

    /**
     * @dev Pauses the contract.
     * Only callable when the contract is not already paused.
     */
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     * Only callable when the contract is paused.
     */
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @dev Prevents the oracle from being changed.
     */
    function setOracle(address) public pure override {
        revert PausableImmutableOraclePoolImmutable();
    }

    /**
     * @dev Prevents the fee from being changed.
     */
    function setFee(uint96) public pure override {
        revert PausableImmutableOraclePoolImmutable();
    }

    /**
     * @dev Pulls `amount` of `token` from the contract and sends them to `msg.sender`.
     * Can only be called when the contract is not paused.
     *
     * Requirements:
     *
     * - `token` must be equal to `TOKEN_IN`.
     * - The `amount` of `token` to be pulled must be less than or equal to the amount of `token` available in the contract.
     *
     * Emits a {Pull} event.
     */
    function pull(address token, uint256 amount) public override whenNotPaused {
        super.pull(token, amount);
    }

    /**
     * @dev Sweeps `amount` of `token` from the contract and sends them to `recipient`.
     * Can only be called when the contract is not paused.
     *
     * Requirements:
     *
     * - `msg.sender` must be the owner.
     *
     * Emits a {Sweep} event.
     */
    function swap(address recipient, uint256 amountIn, uint256 minAmountOut)
        public
        override
        whenNotPaused
        returns (uint256)
    {
        return super.swap(recipient, amountIn, minAmountOut);
    }
}
