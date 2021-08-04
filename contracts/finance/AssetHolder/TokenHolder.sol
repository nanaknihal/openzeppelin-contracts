// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../token/ERC20/utils/SafeERC20.sol";
import "./IAssetHolder.sol";

contract TokenHolder is IAssetHolder {
    IERC20 public token; // should be immutable, but might be read at construction time

    constructor(IERC20 _token) {
        token = _token;
    }

    function _currentBalance() internal view virtual override returns (uint256) {
        return token.balanceOf(address(this));
    }

    function _processPayment(address account, uint256 value) internal virtual override {
        SafeERC20.safeTransfer(token, account, value);
    }
}
