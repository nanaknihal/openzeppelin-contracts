// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../utils/Address.sol";
import "./IAssetHolder.sol";

contract EtherHolder is IAssetHolder {
    function _currentBalance() internal view virtual override returns (uint256) {
        return address(this).balance;
    }

    function _processPayment(address account, uint256 value) internal virtual override {
        Address.sendValue(payable(account), value);
    }
}
