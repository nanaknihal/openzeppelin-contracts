// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "../token/ERC20/ERC20.sol";
import "./AbstractSplitter.sol";
import "./AssetManager.sol";

abstract contract TokenizedETHSplitter is ERC20, AbstractSplitter {
    constructor() AbstractSplitter(AssetManager.ETH()) {}

    receive() external payable {}

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
        _beforeShareTransfer(from, to, amount, totalSupply());
    }
}

abstract contract TokenizedERC20Splitter is ERC20, AbstractSplitter {
    constructor(IERC20 token) AbstractSplitter(AssetManager.ERC20(token)) {}

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
        _beforeShareTransfer(from, to, amount, totalSupply());
    }
}