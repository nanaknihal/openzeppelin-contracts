// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract ISharesManager {
    function _shares(address account) internal view virtual returns (uint256);

    function _totalShares() internal view virtual returns (uint256);

    function _sharesChanged(
        address account,
        uint256 oldShares,
        uint256 newShares,
        uint256 oldTotalShares,
        uint256 newTotalShares
    ) internal virtual {}
}
