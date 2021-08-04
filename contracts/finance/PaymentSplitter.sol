// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Context.sol";
import "../utils/Address.sol";



library Distributions {
    struct Distribution {
        mapping(address => uint256) _values;
        uint256 _total;
    }

    function getValue(Distribution storage distribution, address account) internal view returns (uint256) {
        return distribution._values[account];
    }

    function getTotal(Distribution storage distribution) internal view returns (uint256) {
        return distribution._total;
    }

    function increaseValue(Distribution storage distribution, address account, uint256 value) internal {
        distribution._total += value;
        distribution._values[account] += value;
    }

    function decreaseValue(Distribution storage distribution, address account, uint256 value) internal {
        distribution._total -= value;
        distribution._values[account] -= value;
    }

    function setValue(Distribution storage distribution, address account, uint256 value) internal {
        uint256 total = getTotal(distribution);
        total -= getValue(distribution, account);
        total += value;
        distribution._total = total;
        distribution._values[account] = value;
    }
}



/**
 * @title PaymentSplitter
 * @dev This contract allows to split Ether payments among a group of accounts. The sender does not need to be aware
 * that the Ether will be split in this way, since it is handled transparently by the contract.
 *
 * The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each
 * account to a number of shares. Of all the Ether that this contract receives, each account will then be able to claim
 * an amount proportional to the percentage of total shares they were assigned.
 *
 * `PaymentSplitter` follows a _pull payment_ model. This means that payments are not automatically forwarded to the
 * accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the {release}
 * function.
 */
contract PaymentSplitter is Context {
    using Distributions for Distributions.Distribution;

    Distributions.Distribution private $shares;
    Distributions.Distribution private $released;

    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    /**
     * @dev Creates an instance of `PaymentSplitter` where each account in `payees` is assigned the number of shares at
     * the matching position in the `shares` array.
     *
     * All addresses in `payees` must be non-zero. Both arrays must have the same non-zero length, and there must be no
     * duplicates in `payees`.
     */
    constructor(address[] memory _payees, uint256[] memory _shares) payable {
        require(_payees.length == _shares.length, "PaymentSplitter: payees and shares length mismatch");
        require(_payees.length > 0, "PaymentSplitter: no payees");

        for (uint256 i = 0; i < _payees.length; ++i) {
            _setShares(_payees[i], _shares[i]);
        }
    }

    /**
     * @dev The Ether received will be logged with {PaymentReceived} events. Note that these events are not fully
     * reliable: it's possible for a contract to receive Ether without triggering this function. This only affects the
     * reliability of the events, and not the actual splitting of Ether.
     *
     * To learn more about this see the Solidity documentation for
     * https://solidity.readthedocs.io/en/latest/contracts.html#fallback-function[fallback
     * functions].
     */
    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
    }

    /**
     * @dev Getter for the amount of shares held by an account.
     */
    function shares(address account) public view returns (uint256) {
        return $shares.getValue(account);
    }

    /**
     * @dev Getter for the total shares held by payees.
     */
    function totalShares() public view returns (uint256) {
        return $shares.getTotal();
    }

    /**
     * @dev Getter for the amount of Ether already released to a payee.
     */
    function released(address account) public view returns (uint256) {
        return $released.getValue(account);
    }

    /**
     * @dev Getter for the total amount of Ether already released.
     */
    function totalReleased() public view returns (uint256) {
        return $released.getTotal();
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function release(address payable account) public virtual {
        uint256 totalReceived = _currentBalance() + totalReleased();
        uint256 personalValue = (totalReceived * shares(account)) / totalShares();
        uint256 pendingValue  = personalValue - released(account);

        if (pendingValue > 0) {
            $released.increaseValue(account, pendingValue);

            _processPayment(account, pendingValue);
            emit PaymentReleased(account, pendingValue);
        }
    }

    /**
     * @dev Add a new payee to the contract.
     * @param account The address of the payee to add.
     * @param newShares The number of shares owned by the payee.
     */
    function _updateShares(address account, uint256 newShares) internal virtual {
        uint256 totalReceived = _currentBalance() + totalReleased();
        if (totalReceived > 0) {
            uint256 oldShares = shares(account);
            if (oldShares < newShares) {
                uint256 delta = totalReceived * (newShares - oldShares) / totalShares();
                $released.increaseValue(account, delta);
            } else {
                uint256 delta = totalReceived * (oldShares - newShares) / totalShares();
                $released.decreaseValue(account, delta);
            }
        }
        _setShares(account, newShares);
    }

    function _setShares(address account, uint256 shares) private {
        $shares.setValue(account, shares);
        emit PayeeAdded(account, shares);
    }

    /**
     * @dev abstract virtual function: returns the current balance of the PaymentSplitter
     */
    function _currentBalance() internal view virtual returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev abstract virtual function: send value/assets
     */
    function _processPayment(address payable account, uint256 payment) internal virtual {
        Address.sendValue(account, payment);
    }
}
