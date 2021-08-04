// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../finance/ModularPaymentSplitter.sol";
import "../finance/AssetHolder/TokenHolder.sol";
import "../finance/SharesManager/ERC20Shares.sol";

contract TokenSplitterMock is ModularPaymentSplitter, TokenHolder, ERC20Shares {
    constructor(IERC20 _token) ERC20("PaymentSplitterShare", "shares") TokenHolder(_token) {}

    function mint(address payees, uint256 shares) external {
        _mint(payees, shares);
    }

    function burn(address payees, uint256 shares) external {
        _burn(payees, shares);
    }

    function _sharesChanged(
        address account,
        uint256 oldShares,
        uint256 newShares,
        uint256 oldTotalShares,
        uint256 newTotalShares
    ) internal virtual override(ISharesManager, ModularPaymentSplitter) {
        super._sharesChanged(account, oldShares, newShares, oldTotalShares, newTotalShares);
    }
}
