// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "../utils/math/SafeCast.sol";
import "../utils/structs/Distribution.sol";
import "./AssetManager.sol";

/**
 * @title AbstractSplitter
 * @dev This contract allows to split payments in any fungible asset (supported by the AssetManager library) among a
 * group of accounts. The sender does not need to be aware that the asset will be split in this way, since it is
 * handled transparently by the contract.
 *
 * The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each
 * account to a number of shares through the {_shares} and {_totalShares} virtual function. Of all the assets that this
 * contract receives, each account will then be able to claim an amount proportional to the percentage of total shares
 * they own assigned.
 *
 * `AbstractSplitter` follows a _pull payment_ model. This means that payments are not automatically forwarded to
 * the accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the
 * {release} function.
 *
 * Warning: An abstractSplitter can only process a single asset class, described by the {AssetManager.Asset} object
 * used during construction. Any other asset class will not be recoverable.
 */
abstract contract AbstractSplitter {
    using AssetManager for AssetManager.Asset;
    using Distribution for Distribution.AddressToIntWithTotal;

    AssetManager.Asset private _asset;
    Distribution.AddressToIntWithTotal private _released;

    event PaymentReleased(address to, uint256 amount);

    /**
     * @dev Initialize with an asset handling object.
     */
    constructor(AssetManager.Asset memory asset) {
        _asset = asset;
    }

    /**
     * @dev Internal hook: get shares for an account
     */
    function _shares(address account) internal view virtual returns (uint256);

    /**
     * @dev Internal hook: get total shares
     */
    function _totalShares() internal view virtual returns (uint256);

    /**
     * @dev Asset units up for release.
     */
    function pendingRelease(address account) public view virtual returns (uint256) {
        uint256 amount = _shares(account);
        // if personalShares == 0, there is a risk of totalShares == 0. To avoid div by 0 just return 0
        uint256 allocation = amount > 0 ? _allocation(amount, _totalShares()) : 0;
        return SafeCast.toUint256(SafeCast.toInt256(allocation) - _released.getValue(account));
    }

    /**
     * @dev Triggers a transfer of asset to `account` according to their percentage of the total shares and their
     * previous withdrawals.
     */
    function release(address account) public virtual returns (uint256) {
        uint256 toRelease = pendingRelease(account);
        if (toRelease > 0) {
            _released.incr(account, SafeCast.toInt256(toRelease));
            emit PaymentReleased(account, toRelease);
            _asset.sendValue(account, toRelease);
        }
        return toRelease;
    }

    /**
     * @dev Update release manifest to account to shares movement when payment has not been released. This must be
     * called whenever shares are minted, burned or transfered.
     */
    function _beforeShareTransfer(
        address from,
        address to,
        uint256 amount,
        uint256 supply
    ) internal virtual {
        if (amount > 0 && supply > 0) {
            int256 virtualRelease = SafeCast.toInt256(_allocation(amount, supply));
            if (from != address(0)) {
                _released.decr(from, virtualRelease);
            }
            if (to != address(0)) {
                _released.incr(to, virtualRelease);
            }
        }
    }

    function _allocation(uint256 amount, uint256 supply) private view returns (uint256) {
        return
            (amount * SafeCast.toUint256(SafeCast.toInt256(_asset.getBalance(address(this))) + _released.getTotal())) /
            supply;
    }
}
