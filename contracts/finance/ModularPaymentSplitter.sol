// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "./AssetManager.sol";
import "./SharesManager/ISharesManager.sol";

library Distribution {
    struct AddressToUintWithTotal {
        mapping(address => uint256) _values;
        uint256 _total;
    }

    function getValue(AddressToUintWithTotal storage store, address account) internal view returns (uint256) {
        return store._values[account];
    }

    function getTotal(AddressToUintWithTotal storage store) internal view returns (uint256) {
        return store._total;
    }

    function setValue(AddressToUintWithTotal storage store, address account, uint256 value) internal {
        store._total = store._total - store._values[account] + value;
        store._values[account] = value;
    }

    function incrValue(AddressToUintWithTotal storage store, address account, uint256 value) internal {
        store._total += value;
        store._values[account] += value;
    }

    function decrValue(AddressToUintWithTotal storage store, address account, uint256 value) internal {
        store._total -= value;
        store._values[account] -= value;
    }
}



library PaymentSplitting {
    using AssetManager for AssetManager.Asset;
    using Distribution for Distribution.AddressToUintWithTotal;

    struct Manifest {
        AssetManager.Asset _asset;
        Distribution.AddressToUintWithTotal _released;
    }

    event PaymentReleased(address to, uint256 amount);

    function init(Manifest storage store, AssetManager.Asset memory asset) internal {
        store._asset = asset;
    }

    function released(Manifest storage store, address account) internal view returns (uint256) {
        return store._released.getValue(account);
    }

    function totalReleased(Manifest storage store) internal view returns (uint256) {
        return store._released.getTotal();
    }

    function pendingRelease(
        Manifest storage store,
        address account,
        uint256 shares,
        uint256 totalShares
    ) internal view returns (uint256) {
        uint256 totalReceived = AssetManager.getBalance(store._asset, address(this)) + store._released.getTotal();
        uint256 personalValue = (totalReceived * shares) / totalShares;
        return personalValue - store._released.getValue(account);
    }

    function release(
        Manifest storage store,
        address account,
        uint256 shares,
        uint256 totalShares
    ) internal returns (uint256) {
        uint256 toRelease = pendingRelease(store, account, shares, totalShares);
        if (toRelease > 0) {
            store._released.incrValue(account, toRelease);
            emit PaymentReleased(account, toRelease);
            store._asset.sendValue(account, toRelease);
        }
        return toRelease;
    }

    function rebalance(
        Manifest storage store,
        address account,
        uint256 oldShares,
        uint256 newShares,
        uint256 oldTotalShares
    ) internal {
        uint256 totalReceived = AssetManager.getBalance(store._asset, address(this)) + totalReleased(store);
        if (oldTotalShares > 0 && totalReceived > 0) {
            if (oldShares < newShares) {
                store._released.incrValue(account, (totalReceived * (newShares - oldShares)) / oldTotalShares);
            } else {
                store._released.decrValue(account, (totalReceived * (oldShares - newShares)) / oldTotalShares);
            }
        }
    }
}
















/**
 * @title ModularPaymentSplitter
 * @dev This contract allows to split payments in any fungible asset (supported by the AssetManager library) among a
 * group of accounts. The sender does not need to be aware that the asset will be split in this way, since it is handled
 * transparently by the contract.
 *
 * The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each
 * account to a number of shares through the {ISharesManager} interface. Of all the assets that this contract receives,
 * each account will then be able to claim an amount proportional to the percentage of total shares they own assigned.
 *
 * `ModularPaymentSplitter` follows a _pull payment_ model. This means that payments are not automatically forwarded to
 * the accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the
 * {release} function.
 */
abstract contract ModularPaymentSplitter is ISharesManager {
    using PaymentSplitting for PaymentSplitting.Manifest;

    PaymentSplitting.Manifest private _manifest;

    // From PaymentSplittingdress to, uint256  make part of the AB);
    event PaymentReleased(address to, uint256 amount);

    /**
     * @dev Initialize with an asset handling object.
     */
    constructor(AssetManager.Asset memory asset) {
        _manifest.init(asset);
    }

    /**
     * @dev Getter for the amount of Ether already released to a payee.
     */
    function released(address account) public view returns (uint256) {
        return _manifest.released(account);
    }

    /**
     * @dev Getter for the total amount of Ether already released.
     */
    function totalReleased() public view returns (uint256) {
        return _manifest.totalReleased();
    }

    /**
     * @dev Asset units up for release.
     */
    function pendingRelease(address account) public view virtual returns (uint256) {
        return _manifest.pendingRelease(account, _shares(account), _totalShares());
    }

    /**
     * @dev Triggers a transfer of asset to `account` according to their percentage of the total shares and their
     * previous withdrawals.
     */
    function release(address account) public virtual {
        _manifest.release(account, _shares(account), _totalShares());
    }

    /**
     * @dev Hook to update the release manifest if shares distribution change after some assets have already been
     * received. This hook should be called when updating the shares. For example, for ERC20 based shares, this hook
     * should be triggered by the {ERC20-_beforeTokenTransfer} hook.
     */
    function _sharesChanged(
        address account,
        uint256 oldShares,
        uint256 newShares,
        uint256 oldTotalShares,
        uint256 newTotalShares
    ) internal virtual override {
        super._sharesChanged(account, oldShares, newShares, oldTotalShares, newTotalShares);
        _manifest.rebalance(account, oldShares, newShares, oldTotalShares);
    }
}
