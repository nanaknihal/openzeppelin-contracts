// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./PaymentSplitter.sol";
import "../utils/Address.sol";
import "../token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenSplitter
 * @dev An ERC20 specific version of the {PaymentSplitter}
 */
contract TokenSplitter is PaymentSplitter {
    IERC20 immutable public token;

    constructor (IERC20 _token, address[] memory _payees, uint256[] memory _shares)
    PaymentSplitter(_payees, _shares)
    {
        require(Address.isContract(address(_token)), "TokenSplitter: token is not a contract");
        token = _token;
    }

    receive () external payable virtual override {
        revert("TokenSplitter: ether not supported");
    }

    function _currentBalance() internal view virtual override returns (uint256) {
        return token.balanceOf(address(this));
    }

    function _processPayment(address payable account, uint256 payment) internal virtual override {
        SafeERC20.safeTransfer(token, account, payment);
    }
}
