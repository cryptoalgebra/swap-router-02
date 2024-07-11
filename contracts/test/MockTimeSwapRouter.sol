// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;
pragma abicoder v2;

import '../SwapRouter02.sol';

contract MockTimeSwapRouter02 is SwapRouter02 {
    uint256 time;

    constructor(
        address _factoryV2,
        address poolDeployer,
        address factoryV3,
        address _positionManager,
        address _WETH9
    ) SwapRouter02(_factoryV2, poolDeployer, factoryV3, _positionManager, _WETH9) {}

    function _blockTimestamp() internal view override returns (uint256) {
        return time;
    }

    function setTime(uint256 _time) external {
        time = _time;
    }
}
