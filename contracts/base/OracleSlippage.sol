// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.20;
pragma abicoder v2;

import '../interfaces/IOracleSlippage.sol';

import '@cryptoalgebra/integral-periphery/contracts/base/PeripheryImmutableState.sol';
import '@cryptoalgebra/integral-periphery/contracts/base/BlockTimestamp.sol';
import '@cryptoalgebra/integral-periphery/contracts/libraries/Path.sol';
import '@cryptoalgebra/integral-periphery/contracts/libraries/PoolAddress.sol';
import '@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol';
import '@cryptoalgebra/integral-base-plugin/contracts/libraries/integration/OracleLibrary.sol';
import '@cryptoalgebra/integral-base-plugin/contracts/interfaces/plugins/IVolatilityOracle.sol';

abstract contract OracleSlippage is IOracleSlippage, PeripheryImmutableState, BlockTimestamp {
    using Path for bytes;

    /// @dev Returns the tick as of the beginning of the current block, and as of right now, for the given pool.
    function getBlockStartingAndCurrentTick(IAlgebraPool pool)
        internal
        view
        returns (int24 blockStartingTick, int24 currentTick)
    {
        uint16 observationIndex;
        uint32 observationTimestamp;
        (, currentTick, , , , ) = IAlgebraPool(pool).globalState();

        IVolatilityOracle oracle = IVolatilityOracle(pool.plugin());
        (observationIndex, observationTimestamp) = OracleLibrary.lastTimepointMetadata(address(oracle));
        
        if(observationTimestamp != _blockTimestamp()){
            blockStartingTick = currentTick;
        } else {

            (, , int56 tickCumulative, , , , ) = oracle.timepoints(observationIndex);
            unchecked {
                uint16 prevIndex = observationIndex - 1;
                (bool initialized, uint32 prevTimestamp, int56 prevTickCumulative, , , , ) = oracle.timepoints(prevIndex);
                require(initialized, 'TNI');
                uint32 delta = observationTimestamp - prevTimestamp;
                blockStartingTick = int24((tickCumulative - prevTickCumulative) / int56(int32(delta)));
            }
        }
 
    }

    /// @dev Virtual function to get pool addresses that can be overridden in tests.
    function getPoolAddress(
        address tokenA,
        address tokenB
    ) internal view virtual returns (IAlgebraPool pool) {
        pool = IAlgebraPool(PoolAddress.computeAddress(poolDeployer, PoolAddress.getPoolKey(tokenA, tokenB)));
    }

    /// @dev Returns the synthetic time-weighted average tick as of secondsAgo, as well as the current tick,
    /// for the given path. Returned synthetic ticks always represent tokenOut/tokenIn prices,
    /// meaning lower ticks are worse.
    function getSyntheticTicks(bytes memory path, uint32 secondsAgo)
        internal
        view
        returns (int256 syntheticAverageTick, int256 syntheticCurrentTick)
    {
        bool lowerTicksAreWorse;

        uint256 numPools = path.numPools();
        address previousTokenIn;
        for (uint256 i = 0; i < numPools; i++) {
            // this assumes the path is sorted in swap order
            (address tokenIn, address tokenOut) = path.decodeFirstPool();
            IAlgebraPool pool = getPoolAddress(tokenIn, tokenOut);

            // get the average and current ticks for the current pool
            int256 averageTick;
            int256 currentTick;
            if (secondsAgo == 0) {
                // we optimize for the secondsAgo == 0 case, i.e. since the beginning of the block
                (averageTick, currentTick) = getBlockStartingAndCurrentTick(pool);
            } else {
                averageTick = OracleLibrary.consult(address(pool.plugin()), secondsAgo);
                (, currentTick, , , ,) = IAlgebraPool(pool).globalState();
            }

            if (i == numPools - 1) {
                // if we're here, this is the last pool in the path, meaning tokenOut represents the
                // destination token. so, if tokenIn < tokenOut, then tokenIn is token0 of the last pool,
                // meaning the current running ticks are going to represent tokenOut/tokenIn prices.
                // so, the lower these prices get, the worse of a price the swap will get
                lowerTicksAreWorse = tokenIn < tokenOut;
            } else {
                // if we're here, we need to iterate over the next pool in the path
                path = path.skipToken();
                previousTokenIn = tokenIn;
            }

            // accumulate the ticks derived from the current pool into the running synthetic ticks,
            // ensuring that intermediate tokens "cancel out"
            bool add = (i == 0) || (previousTokenIn < tokenIn ? tokenIn < tokenOut : tokenOut < tokenIn);
            if (add) {
                syntheticAverageTick += averageTick;
                syntheticCurrentTick += currentTick;
            } else {
                syntheticAverageTick -= averageTick;
                syntheticCurrentTick -= currentTick;
            }
        }

        // flip the sign of the ticks if necessary, to ensure that the lower ticks are always worse
        if (!lowerTicksAreWorse) {
            syntheticAverageTick *= -1;
            syntheticCurrentTick *= -1;
        }
    }

    /// @dev For each passed path, fetches the synthetic time-weighted average tick as of secondsAgo,
    /// as well as the current tick. Then, synthetic ticks from all paths are subjected to a weighted
    /// average, where the weights are the fraction of the total input amount allocated to each path.
    /// Returned synthetic ticks always represent tokenOut/tokenIn prices, meaning lower ticks are worse.
    /// Paths must all start and end in the same token.
    function getSyntheticTicks(
        bytes[] memory paths,
        uint128[] memory amounts,
        uint32 secondsAgo
    ) internal view returns (int256 averageSyntheticAverageTick, int256 averageSyntheticCurrentTick) {
        require(paths.length == amounts.length);

        WeightedTickData[] memory weightedSyntheticAverageTicks =
            new WeightedTickData[](paths.length);
        WeightedTickData[] memory weightedSyntheticCurrentTicks =
            new WeightedTickData[](paths.length);

        for (uint256 i = 0; i < paths.length; i++) {
            (int256 syntheticAverageTick, int256 syntheticCurrentTick) = getSyntheticTicks(paths[i], secondsAgo);
            weightedSyntheticAverageTicks[i].tick = int24(syntheticAverageTick);
            weightedSyntheticCurrentTicks[i].tick = int24(syntheticCurrentTick);
            weightedSyntheticAverageTicks[i].weight = amounts[i];
            weightedSyntheticCurrentTicks[i].weight = amounts[i];
        }

        averageSyntheticAverageTick = getWeightedArithmeticMeanTick(weightedSyntheticAverageTicks);
        averageSyntheticCurrentTick = getWeightedArithmeticMeanTick(weightedSyntheticCurrentTicks);
    }

    /// @inheritdoc IOracleSlippage
    function checkOracleSlippage(
        bytes memory path,
        uint24 maximumTickDivergence,
        uint32 secondsAgo
    ) external view override {
        (int256 syntheticAverageTick, int256 syntheticCurrentTick) = getSyntheticTicks(path, secondsAgo);
        require(syntheticAverageTick - syntheticCurrentTick < int256(int24(maximumTickDivergence)), 'TD');
    }

    /// @inheritdoc IOracleSlippage
    function checkOracleSlippage(
        bytes[] memory paths,
        uint128[] memory amounts,
        uint24 maximumTickDivergence,
        uint32 secondsAgo
    ) external view override {
        (int256 averageSyntheticAverageTick, int256 averageSyntheticCurrentTick) =
            getSyntheticTicks(paths, amounts, secondsAgo);
        require(averageSyntheticAverageTick - averageSyntheticCurrentTick < int256(int24(maximumTickDivergence)), 'TD');
    }

    struct WeightedTickData {
        int24 tick;
        uint128 weight;
    }


    function getWeightedArithmeticMeanTick(WeightedTickData[] memory weightedTickData)
        private
        pure
        returns (int24 weightedArithmeticMeanTick)
    {
        // Accumulates the sum of products between each tick and its weight
        int256 numerator;

        // Accumulates the sum of the weights
        uint256 denominator;

        // Products fit in 152 bits, so it would take an array of length ~2**104 to overflow this logic
        for (uint256 i; i < weightedTickData.length; i++) {
            numerator += weightedTickData[i].tick * int256(int128(weightedTickData[i].weight));
            denominator += weightedTickData[i].weight;
        }

        weightedArithmeticMeanTick = int24(numerator / int256(denominator));
        // Always round to negative infinity
        if (numerator < 0 && (numerator % int256(denominator) != 0)) weightedArithmeticMeanTick--;
    }
}
