// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../token/ERC20/ERC20.sol";
import "./ISharesManager.sol";

abstract contract ERC20Shares is ISharesManager, ERC20 {
    function _shares(address account) internal view virtual override returns (uint256) {
        return balanceOf(account);
    }

    function _totalShares() internal view virtual override returns (uint256) {
        return totalSupply();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        uint256 oldTotalSupply = totalSupply();
        uint256 newTotalSupply = oldTotalSupply + (from == address(0) ? amount : 0) - (to == address(0) ? amount : 0);

        if (from != address(0)) {
            uint256 oldBalance = balanceOf(from);
            uint256 newBalance = oldBalance - amount;
            _sharesChanged(from, oldBalance, newBalance, oldTotalSupply, newTotalSupply);
        }

        if (to != address(0)) {
            uint256 oldBalance = balanceOf(to);
            uint256 newBalance = oldBalance + amount;
            _sharesChanged(to, oldBalance, newBalance, oldTotalSupply, newTotalSupply);
        }
    }
}
