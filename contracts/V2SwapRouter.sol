// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.20;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './interfaces/IV2SwapRouter.sol';
import './base/ImmutableState.sol';
import './base/PeripheryPaymentsWithFeeExtended.sol';
import './libraries/Constants.sol';
import './libraries/UniswapV2Library.sol';

/// @title Uniswap V2 Swap Router
/// @notice Router for stateless execution of swaps against Uniswap V2
abstract contract V2SwapRouter is IV2SwapRouter, ImmutableState, PeripheryPaymentsWithFeeExtended {

    // supports fee-on-transfer tokens
    // requires the initial amount to have already been sent to the first pair
    function _swap(Route[] memory routes, address _to) private {
        for (uint256 i; i < routes.length; i++) {
            (address input, address output) = (routes[i].from, routes[i].to);
            (address token0, ) = UniswapV2Library.sortTokens(input, output);
            IBaseV1Pair pair = IBaseV1Pair(UniswapV2Library.pairFor(factoryV2, routes[i].from, routes[i].to, routes[i].stable));
            uint256 amountInput;
            uint256 amountOutput;
            // scope to avoid stack too deep errors
            {
                bool stable = routes[i].stable;
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, ) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                (amountOutput,) = UniswapV2Library.getAmountOut(factoryV2, amountInput, input, output, stable);
            }
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            address to = i < routes.length - 1 ? UniswapV2Library.pairFor(factoryV2, routes[i+1].from, routes[i+1].to, routes[i+1].stable) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    /// @inheritdoc IV2SwapRouter
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to
    ) external payable override returns (uint256 amountOut) {
        // use amountIn == Constants.CONTRACT_BALANCE as a flag to swap the entire balance of the contract
        bool hasAlreadyPaid;
        if (amountIn == Constants.CONTRACT_BALANCE) {
            hasAlreadyPaid = true;
            amountIn = IERC20(routes[0].from).balanceOf(address(this));
        }

        pay(
            routes[0].from,
            hasAlreadyPaid ? address(this) : msg.sender,
            UniswapV2Library.pairFor(factoryV2, routes[0].from, routes[0].to, routes[0].stable),
            amountIn
        );

        // find and replace to addresses
        if (to == Constants.MSG_SENDER) to = msg.sender;
        else if (to == Constants.ADDRESS_THIS) to = address(this);

        uint256 balanceBefore = IERC20(routes[routes.length - 1].to).balanceOf(to);

        _swap(routes, to);

        amountOut = IERC20(routes[routes.length - 1].to).balanceOf(to) - balanceBefore;
        require(amountOut >= amountOutMin, 'Too little received');
    }


}
