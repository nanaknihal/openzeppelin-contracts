// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../TokenSplitter.sol";
import "../../token/ERC20/extensions/ERC20Wrapper.sol";

/**
 * @title PaymentSplitterShares
 * @dev Stil contract splits tokens sent to this contract according to the
 * share of staked tokens of users (in the same token).
 */
contract PaymentSplitterShares is ERC20Wrapper, TokenSplitter {
    constructor(
        string memory name,
        string memory symbol,
        IERC20 token
    ) ERC20(name, symbol) ERC20Wrapper(token) TokenSplitter(token, new address[](0), new uint256[](0)) {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._afterTokenTransfer(from, to, amount);
        _updateShares(from, balanceOf(from));
        _updateShares(to, balanceOf(to));
    }

    function _currentBalance() internal view virtual override returns (uint256) {
        return token.balanceOf(address(this)) - totalSupply();
    }
}
