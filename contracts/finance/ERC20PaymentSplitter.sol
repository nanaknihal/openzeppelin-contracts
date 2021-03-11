// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./PaymentSplitter.sol";
import "../utils/Address.sol";
import "../token/ERC20/utils/SafeERC20.sol";

/**
 * @title ERC20PaymentSplitter
 * @dev An ERC20 specific version of the {PaymentSplitter}

 */
contract ERC20PaymentSplitter is PaymentSplitter {
    IERC20 immutable public token;

    constructor (address token_, address[] memory payees_, uint256[] memory shares_) PaymentSplitter(payees_, shares_) {
        require(Address.isContract(token_), "ERC20PaymentSplitter: token is not a contract");
        token = IERC20(token_);
    }

    receive () external payable virtual override {
        revert("ERC20PaymentSplitter: ether not supported");
    }

    function _currentBalance() internal view virtual override returns (uint256) {
        return token.balanceOf(address(this));
    }

    function _processPayment(address payable account, uint256 payment) internal virtual override {
        SafeERC20.safeTransfer(token, account, payment);
    }
}
