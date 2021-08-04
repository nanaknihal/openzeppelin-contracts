// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract IAssetHolder {
    function _currentBalance() internal view virtual returns (uint256);

    function _processPayment(address account, uint256 value) internal virtual;
}
