// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title Safe casting methods
library SafeCastExtend {
    /// @notice Cast a uint256 to a uint128, revert on overflow
    /// @param y The uint256 to be downcasted
    /// @return z The downcasted integer, now type uint128
    function toUint128(uint256 y) internal pure returns (uint128 z) {
        require((z = uint128(y)) == y);
    }
}
