// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Address.sol";
import "../token/ERC20/IERC20.sol";
import "../token/ERC20/utils/SafeERC20.sol";

library AssetManager {
    struct Asset {
        function(Asset memory, address) internal view returns (uint256) _balanceHandler;
        function(Asset memory, address, uint256) internal _transferHandler;
        bytes _data;
    }

    function getBalance(Asset memory asset, address account) internal view returns (uint256) {
        return asset._balanceHandler(asset, account);
    }

    function sendValue(
        Asset memory asset,
        address account,
        uint256 value
    ) internal {
        asset._transferHandler(asset, account, value);
    }

    /// ETH
    // solhint-disable-next-line func-name-mixedcase
    function ETH() internal pure returns (Asset memory result) {
        result._balanceHandler = _ethBalance;
        result._transferHandler = _ethTransfer;
    }

    function _ethBalance(
        Asset memory, /*asset*/
        address account
    ) private view returns (uint256) {
        return account.balance;
    }

    function _ethTransfer(
        Asset memory, /*asset*/
        address account,
        uint256 value
    ) private {
        Address.sendValue(payable(account), value);
    }

    /// ERC20
    // solhint-disable-next-line func-name-mixedcase
    function ERC20(IERC20 token) internal pure returns (Asset memory result) {
        result._balanceHandler = _erc20Balance;
        result._transferHandler = _erc20Transfer;
        result._data = abi.encode(token);
    }

    function _erc20Balance(Asset memory asset, address account) private view returns (uint256) {
        return abi.decode(asset._data, (IERC20)).balanceOf(account);
    }

    function _erc20Transfer(
        Asset memory asset,
        address account,
        uint256 value
    ) private {
        SafeERC20.safeTransfer(abi.decode(asset._data, (IERC20)), account, value);
    }
}
