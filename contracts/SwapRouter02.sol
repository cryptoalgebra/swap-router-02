// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.20;
pragma abicoder v2;

import '@cryptoalgebra/integral-periphery/contracts/base/SelfPermit.sol';
import '@cryptoalgebra/integral-periphery/contracts/base/PeripheryImmutableState.sol';

import './interfaces/ISwapRouter02.sol';
import './V2SwapRouter.sol';
import './V3SwapRouter.sol';
import './base/ApproveAndCall.sol';
import './base/MulticallExtended.sol';

/// @title Uniswap V2 and V3 Swap Router
contract SwapRouter02 is ISwapRouter02, V2SwapRouter, V3SwapRouter, ApproveAndCall, MulticallExtended, SelfPermit {
    constructor(
        address _factoryV2,
        address poolDeployer,
        address factoryV3,
        address _positionManager,
        address _WNativeToken
    ) ImmutableState(_factoryV2, _positionManager) PeripheryImmutableState(factoryV3, _WNativeToken, poolDeployer) {}
}
