// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./AssetManager.sol";
import "./SharesManager/ISharesManager.sol";

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
abstract contract ModularPaymentSplitter is ISharesManager {
    using AssetManager for AssetManager.Asset;

    AssetManager.Asset private _asset;

    mapping(address => uint256) private _released;
    uint256 private _totalReleased;

    event PaymentReleased(address to, uint256 amount);

    constructor(AssetManager.Asset memory asset) {
        _asset = asset;
    }

    /**
     * @dev Getter for the amount of Ether already released to a payee.
     */
    function released(address account) public view returns (uint256) {
        return _released[account];
    }

    /**
     * @dev Getter for the total amount of Ether already released.
     */
    function totalReleased() public view returns (uint256) {
        return _totalReleased;
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function pendingRelease(address account) public view virtual returns (uint256) {
        uint256 totalReceived = _asset.getBalance(address(this)) + totalReleased();
        uint256 personalValue = (totalReceived * _shares(account)) / _totalShares();
        return personalValue - released(account);
    }

    function release(address account) public virtual {
        uint256 toRelease = pendingRelease(account);
        if (toRelease > 0) {
            _released[account] += toRelease;
            _totalReleased += toRelease;

            _asset.sendValue(account, toRelease);
            emit PaymentReleased(account, toRelease);
        }
    }

    function _sharesChanged(
        address account,
        uint256 oldShares,
        uint256 newShares,
        uint256 oldTotalShares,
        uint256 newTotalShares
    ) internal virtual override {
        super._sharesChanged(account, oldShares, newShares, oldTotalShares, newTotalShares);

        uint256 totalReceived = _asset.getBalance(address(this)) + totalReleased();
        if (oldTotalShares > 0 && totalReceived > 0) {
            if (oldShares < newShares) {
                uint256 delta = (totalReceived * (newShares - oldShares)) / oldTotalShares;
                _released[account] += delta;
                _totalReleased += delta;
            } else {
                uint256 delta = (totalReceived * (oldShares - newShares)) / oldTotalShares;
                _released[account] -= delta;
                _totalReleased -= delta;
            }
        }
    }
}
