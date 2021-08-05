// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "./AssetManager.sol";
import "./SharesManager/ISharesManager.sol";

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
    using AssetManager for AssetManager.Asset;

    // Asset handling functors, support ETH, ERC20 & ERC1155
    AssetManager.Asset private _asset;

    // Release manifest
    mapping(address => uint256) private _released;
    uint256 private _totalReleased;

    /**
     * @dev Emitted when `amount` units are released to `to`.
     */
    event PaymentReleased(address to, uint256 amount);

    /**
     * @dev Initialize with an asset handling object.
     */
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
     *
     */
    function pendingRelease(address account) public view virtual returns (uint256) {
        uint256 totalReceived = _asset.getBalance(address(this)) + totalReleased();
        uint256 personalValue = (totalReceived * _shares(account)) / _totalShares();
        return personalValue - released(account);
    }

    /**
     * @dev Triggers a transfer of asset to `account` according to their percentage of the total shares and their
     * previous withdrawals.
     */
    function release(address account) public virtual {
        uint256 toRelease = pendingRelease(account);
        if (toRelease > 0) {
            _released[account] += toRelease;
            _totalReleased += toRelease;

            _asset.sendValue(account, toRelease);
            emit PaymentReleased(account, toRelease);
        }
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
