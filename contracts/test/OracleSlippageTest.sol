// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.20;
pragma abicoder v2;

import '../base/OracleSlippage.sol';

contract OracleSlippageTest is OracleSlippage {
    mapping(address => mapping(address => IAlgebraPool)) private pools;
    uint256 internal time;

    constructor(address _factory, address _WETH9, address poolDeployer) PeripheryImmutableState(_factory, _WETH9, poolDeployer) {}

    function setTime(uint256 _time) external {
        time = _time;
    }

    function _blockTimestamp() internal view override returns (uint256) {
        return time;
    }

    function registerPool(
        IAlgebraPool pool,
        address tokenIn,
        address tokenOut
    ) external {
        pools[tokenIn][tokenOut]= pool;
        pools[tokenOut][tokenIn] = pool;
    }

    function getPoolAddress(
        address tokenA,
        address tokenB
    ) internal view override returns (IAlgebraPool pool) {
        pool = pools[tokenA][tokenB];
    }

    function testGetBlockStartingAndCurrentTick(IAlgebraPool pool)
        external
        view
        returns (int24 blockStartingTick, int24 currentTick)
    {
        return getBlockStartingAndCurrentTick(pool);
    }

    function testGetSyntheticTicks(bytes memory path, uint32 secondsAgo)
        external
        view
        returns (int256 syntheticAverageTick, int256 syntheticCurrentTick)
    {
        return getSyntheticTicks(path, secondsAgo);
    }

    function testGetSyntheticTicks(
        bytes[] memory paths,
        uint128[] memory amounts,
        uint32 secondsAgo
    ) external view returns (int256 averageSyntheticAverageTick, int256 averageSyntheticCurrentTick) {
        return getSyntheticTicks(paths, amounts, secondsAgo);
    }
}
