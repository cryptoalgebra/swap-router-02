// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

import '@cryptoalgebra/integral-periphery/contracts/interfaces/IPeripheryPaymentsWithFee.sol';

import './IPeripheryPaymentsExtended.sol';

/// @title Periphery Payments With Fee Extended
/// @notice Functions to ease deposits and withdrawals of ETH
interface IPeripheryPaymentsWithFeeExtended is IPeripheryPaymentsExtended, IPeripheryPaymentsWithFee {
    /// @notice Unwraps the contract's WNativeToken balance and sends it to msg.sender as ETH, with a percentage between
    /// 0 (exclusive), and 1 (inclusive) going to feeRecipient
    /// @dev The amountMinimum parameter prevents malicious contracts from stealing WNativeToken from users.
    function unwrapWNativeTokenWithFee(
        uint256 amountMinimum,
        uint256 feeBips,
        address feeRecipient
    ) external payable;

    /// @notice Transfers the full amount of a token held by this contract to msg.sender, with a percentage between
    /// 0 (exclusive) and 1 (inclusive) going to feeRecipient
    /// @dev The amountMinimum parameter prevents malicious contracts from stealing the token from users
    function sweepTokenWithFee(
        address token,
        uint256 amountMinimum,
        uint256 feeBips,
        address feeRecipient
    ) external payable;
}
