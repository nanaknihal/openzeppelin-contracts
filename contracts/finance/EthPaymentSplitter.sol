// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./PaymentSplitter.sol";
import "../utils/Address.sol";

/**
 * @title EthPaymentSplitter
 * @dev An Ether specific version of the abstract {PaymentSplitter}
 */
contract EthPaymentSplitter is PaymentSplitter {
    constructor (address[] memory payees_, uint256[] memory shares_) payable PaymentSplitter(payees_, shares_) {}

    /**
     * @dev The Ether received will be logged with {PaymentReceived} events. Note that these events are not fully
     * reliable: it's possible for a contract to receive Ether without triggering this function. This only affects the
     * reliability of the events, and not the actual splitting of Ether.
     *
     * To learn more about this see the Solidity documentation for
     * https://solidity.readthedocs.io/en/latest/contracts.html#fallback-function[fallback
     * functions].
     */
    receive () external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
    }

    function _currentBalance() internal view virtual override returns (uint256) {
        return address(this).balance;
    }

    function _processPayment(address payable account, uint256 payment) internal virtual override {
        Address.sendValue(account, payment);
    }
}
