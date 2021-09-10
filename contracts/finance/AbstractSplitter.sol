// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "../token/ERC20/ERC20.sol";
import "./AssetManager.sol";

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

    struct AddressToIntWithTotal {
        mapping(address => int256) _values;
        int256 _total;
    }

    function getValue(AddressToIntWithTotal storage store, address account) internal view returns (int256) {
        return store._values[account];
    }

    function getTotal(AddressToIntWithTotal storage store) internal view returns (int256) {
        return store._total;
    }

    function setValue(AddressToIntWithTotal storage store, address account, int256 value) internal {
        store._total = store._total - store._values[account] + value;
        store._values[account] = value;
    }

    function incrValue(AddressToIntWithTotal storage store, address account, int256 value) internal {
        store._total += value;
        store._values[account] += value;
    }

    function decrValue(AddressToIntWithTotal storage store, address account, int256 value) internal {
        store._total -= value;
        store._values[account] -= value;
    }
}

/**
 * @title AbstractSplitter
 * @dev This contract allows to split payments in any fungible asset (supported by the AssetManager library) among a
 * group of accounts. The sender does not need to be aware that the asset will be split in this way, since it is handled
 * transparently by the contract.
 *
 * The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each
 * account to a number of shares through the {ISharesManager} interface. Of all the assets that this contract receives,
 * each account will then be able to claim an amount proportional to the percentage of total shares they own assigned.
 *
 * `AbstractSplitter` follows a _pull payment_ model. This means that payments are not automatically forwarded to
 * the accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the
 * {release} function.
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
     * @dev Asset units up for release.
     */
    function pendingRelease(address account) public view virtual returns (uint256) {
        int256 personalShares = int256(_shares(account));
        // if personalShares == 0, there is a risk of totalShares == 0. To avoid div by 0 just return 0
        int256 allocation = personalShares > 0
            ? personalShares * (int256(_asset.getBalance(address(this))) + _released.getTotal()) / int256(_totalShares())
            : int256(0);

        return uint256(allocation - _released.getValue(account));
    }

    /**
     * @dev Triggers a transfer of asset to `account` according to their percentage of the total shares and their
     * previous withdrawals.
     */
    function release(address account) public virtual returns (uint256) {
        uint256 toRelease = pendingRelease(account);
        if (toRelease > 0) {
            _released.incrValue(account, int256(toRelease));
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
            uint256 virtualRelease = amount * uint256(int256(_asset.getBalance(address(this))) + _released.getTotal()) / supply;
            if (from != address(0)) {
                _released.decrValue(from, int256(virtualRelease));
            }
            if (to != address(0)) {
                _released.incrValue(to, int256(virtualRelease));
            }
        }
    }

    /**
     * @dev Internal hook: get shares for an account
     */
    function _shares(address account) internal view virtual returns (uint256);

    /**
     * @dev Internal hook: get total shares
     */
    function _totalShares() internal view virtual returns (uint256);
}







abstract contract TokenizedETHSplitter is ERC20, AbstractSplitter {
    constructor()
    AbstractSplitter(AssetManager.ETH())
    {}

    function _shares(address account) internal view virtual override returns (uint256) {
        return balanceOf(account);
    }

    function _totalShares() internal view virtual override returns (uint256) {
        return totalSupply();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        _beforeShareTransfer(from, to, amount, totalSupply());
    }
}

abstract contract TokenizedERC20Splitter is ERC20, AbstractSplitter {
    constructor(IERC20 token)
    AbstractSplitter(AssetManager.ERC20(token))
    {}

    function _shares(address account) internal view virtual override returns (uint256) {
        return balanceOf(account);
    }

    function _totalShares() internal view virtual override returns (uint256) {
        return totalSupply();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        _beforeShareTransfer(from, to, amount, totalSupply());
    }
}
