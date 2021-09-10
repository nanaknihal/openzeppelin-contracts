// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../finance/TokenizedSplitter.sol";

contract TokenizedETHSplitterMock is TokenizedETHSplitter {
    constructor() ERC20("Payment Splitter Shares", "PSS") TokenizedETHSplitter() {}

    function mint(address payees, uint256 shares) external {
        _mint(payees, shares);
    }

    function burn(address payees, uint256 shares) external {
        _burn(payees, shares);
    }
}

contract TokenizedERC20SplitterMock is TokenizedERC20Splitter {
    constructor(IERC20 _token) ERC20("Payment Splitter Shares", "PSS") TokenizedERC20Splitter(_token) {}

    function mint(address payees, uint256 shares) external {
        _mint(payees, shares);
    }

    function burn(address payees, uint256 shares) external {
        _burn(payees, shares);
    }
}
