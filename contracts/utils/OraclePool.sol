// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IOracle} from "../interfaces/IOracle.sol";
import {IOraclePool} from "../interfaces/IOraclePool.sol";

/**
 * @title OraclePool Contract
 * @dev A contract that allows to swap `TOKEN_IN` for `TOKEN_OUT` using the exchange rate provided by an oracle.
 * This contract is not compatible with transfer tax tokens.
 * The `SENDER` account is the only account allowed to call the swap and pull functions.
 * It is expected that it takes care of rebalancing the tokens in the contract as this contract only allows to swap `TOKEN_IN` for `TOKEN_OUT`.
 */
contract OraclePool is Ownable2Step, IOraclePool {
    using SafeERC20 for IERC20;

    address public immutable override SENDER;
    address public immutable override TOKEN_IN;
    address public immutable override TOKEN_OUT;

    IOracle private _oracle;
    uint96 private _fee;

    /**
     * @dev Modifier to check if the sender is the expected account.
     */
    modifier onlySender() {
        _checkSender();
        _;
    }

    /**
     * @dev Sets the immutable values for {SENDER}, {TOKEN_IN}, {TOKEN_OUT} and the initial values for the oracle, the swap fee and the owner.
     *
     * The `SENDER` account is the only account allowed to call the swap and pull functions.
     * The `TOKEN_IN` and `TOKEN_OUT` addresses are the addresses of the tokens to be swapped.
     * The `oracle` address is the address of the oracle contract.
     * The `fee` is the fee to be applied to each swap (in 1e18 scale).
     * The `initialOwner` is the address of the initial owner.
     */
    constructor(address sender, address tokenIn, address tokenOut, address oracle, uint96 fee, address initialOwner)
        Ownable(initialOwner)
    {
        SENDER = sender;

        TOKEN_IN = tokenIn;
        TOKEN_OUT = tokenOut;

        _setOracle(IOracle(oracle));
        _setFee(fee);
    }

    /**
     * @dev Returns the address of the oracle contract.
     */
    function getOracle() public view virtual override returns (address) {
        return address(_oracle);
    }

    /**
     * @dev Returns the fee to be applied to each swap (in 1e18 scale).
     */
    function getFee() public view virtual override returns (uint96) {
        return _fee;
    }

    /**
     * @dev Sets the oracle contract address.
     */
    function setOracle(address oracle) public virtual override onlyOwner {
        _setOracle(IOracle(oracle));
    }

    /**
     * @dev Sets the fee to be applied to each swap (in 1e18 scale).
     *
     * Requirements:
     *
     * - `fee` must be less than or equal to 1e18.
     */
    function setFee(uint96 fee) public virtual override onlyOwner {
        _setFee(fee);
    }

    /**
     * @dev Swaps `amountIn` of `TOKEN_IN` for at least `minAmountOut` of `TOKEN_OUT` and sends them to `recipient`.
     * It uses the oracle to get the price of `TOKEN_IN` in `TOKEN_OUT`. A fee is applied to the amount of tokens to be swapped.
     * The fee is kept in this contract and will be used to pay for the gas price and the potential exchange rate deviation when the
     * `TOKEN_IN` is exchanged for `TOKEN_OUT` by the sender.
     *
     * Requirements:
     *
     * - `msg.sender` must be the `SENDER` account.
     * - `oracle` must be set.
     * - The amount of `TOKEN_OUT` to be received must be greater than or equal to `minAmountOut`.
     * - The amount of `TOKEN_OUT` available in the contract must be greater than or equal to the amount of `TOKEN_OUT` to be received.
     * - The `msg.sender` must have approved the contract to spend at least `amountIn` of `TOKEN_IN`.
     *
     * Emits a {Swap} event.
     */
    function swap(address recipient, uint256 amountIn, uint256 minAmountOut)
        public
        virtual
        override
        onlySender
        returns (uint256)
    {
        if (amountIn == 0) revert OraclePoolZeroAmountIn();

        uint256 feeAmount = amountIn * _fee / 1e18;

        IOracle oracle = _oracle;
        if (address(oracle) == address(0)) revert OraclePoolOracleNotSet();

        uint256 price = oracle.getLatestAnswer();
        uint256 amountOut = (amountIn - feeAmount) * 1e18 / price;

        if (amountOut < minAmountOut) revert OraclePoolInsufficientAmountOut(amountOut, minAmountOut);

        uint256 availableOut = IERC20(TOKEN_OUT).balanceOf(address(this));
        if (amountOut > availableOut) revert OraclePoolInsufficientTokenOut(amountOut, availableOut);

        emit Swap(recipient, amountIn, amountOut);

        IERC20(TOKEN_IN).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(TOKEN_OUT).safeTransfer(recipient, amountOut);

        return amountOut;
    }

    /**
     * @dev Pulls `amount` of `token` from the contract and sends them to `msg.sender`.
     *
     * Requirements:
     *
     * - `token` must be equal to `TOKEN_IN`.
     * - The `amount` of `token` to be pulled must be less than or equal to the amount of `token` available in the contract.
     *
     * Emits a {Pull} event.
     */
    function pull(address token, uint256 amount) public virtual override onlySender {
        if (token != TOKEN_IN) revert OraclePoolPullNotAllowed(token);

        uint256 available = IERC20(token).balanceOf(address(this));
        if (amount > available) revert OraclePoolInsufficientToken(token, amount, available);

        emit Pull(token, msg.sender, amount);

        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Sweeps `amount` of `token` from the contract and sends them to `recipient`.
     *
     * Requirements:
     *
     * - `msg.sender` must be the owner.
     *
     * Emits a {Sweep} event.
     */
    function sweep(address token, address recipient, uint256 amount) public virtual override onlyOwner {
        emit Sweep(token, recipient, amount);

        IERC20(token).safeTransfer(recipient, amount);
    }

    /**
     * @dev Reverts if the sender is not the expected account.
     */
    function _checkSender() internal view virtual {
        if (msg.sender != SENDER) revert OraclePoolUnauthorizedAccount(msg.sender);
    }

    /**
     * @dev Sets the oracle contract. Can be set to the zero address to prevent the swap function from being called.
     */
    function _setOracle(IOracle oracle) internal virtual {
        _oracle = oracle;

        emit OracleUpdated(address(oracle));
    }

    /**
     * @dev Sets the fee to be applied to each swap (in 1e18 scale).
     */
    function _setFee(uint96 fee) internal virtual {
        if (fee > 1e18) revert OraclePoolFeeTooHigh();

        _fee = fee;

        emit FeeUpdated(fee);
    }
}
