pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "hardhat/console.sol";

// NOTE: assumes fixed supply, makes sure nobody can mint more if using this ... or does it not assume this?/

contract ERC20Dividends is ERC20 {
  using Math for uint256;
  event ERC20PaymentReleased(IERC20 indexed token, address to, uint256 amount);
  event PaymentReceived(address from, uint256 amount);

  IERC20 public paymentToken;
  uint256 private _totalReleased;
  mapping(address => uint256) private _released;
  mapping(address => uint256) private _withheld;

  constructor(string memory name, string memory symbol, IERC20 paymentToken_) ERC20(name, symbol) public payable {
    paymentToken = paymentToken_;
    _mint(msg.sender, 1000000000 * 10 ** decimals());
  }


  function totalReleased() public view returns (uint256) {
      return _totalReleased;
  }

  function released(address account) public view returns (uint256) {
      return _released[account];
  }

  // TEST THIS
  function withheld(address account) public view returns (uint256) {
      return _withheld[account];
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
    //this is not the most gas-efficient, as it is running this if statement for every transfer when it only needs it upon initializating
    //but it's the easiest way to allow _mint() to be called when totalSupply is 0. totalSupply can only be 0 during initialization (as long as it's initialized with some supply) as this contract does not have public burning functions
    //it's a low overhead though
    if(totalSupply() == 0){
      return;
    }
    uint256 totalReceived = paymentToken.balanceOf(address(this)) + totalReleased();
    // could sacrifice code readability in these two lines to save a bit of gas:
    uint256 owedToFromShares = (totalReceived * balanceOf(from)) / totalSupply();
    uint256 owedToTheseShares = totalReceived * amount / totalSupply();

    // dividendValue is how much is owed to shareholder of *amount* shares, minus what is being withheld. however, if withholding is greater than dividend value, it should just be 0, not negative
    uint256 dividendValue = pendingPayment(from);
    // instead of witholding from msg.sender (as public-facing release()) does, withold from the recipient of shares
    _release(from, dividendValue);
    _withheld[to] += owedToTheseShares;
    // get rid of any withholdings that are now in excess of what the account shares are owed
    _withheld[from] = owedToFromShares - owedToTheseShares;
  }

  function release(uint256 amount) public {
      _release(msg.sender, amount);
      // is it safe to have this happen AFTER _release? could anything fail, preventing withholding after _release? I don't think so, but it concerns me
      _withheld[msg.sender] += amount;
  }

  function _release(address account, uint256 amount) private {
    require(balanceOf(account) > 0, "ERC20Dividends: account has no shares");
    require(amount <= pendingPayment(account), "ERC20Dividends: amount requested exceeds amount owed");

    // _released[account] += amount;
    _totalReleased += amount;

    SafeERC20.safeTransfer(paymentToken, account, amount);
    emit ERC20PaymentReleased(paymentToken, account, amount);
  }

  function pendingPayment(address account) public view returns (uint256) {
      uint256 totalReceived = paymentToken.balanceOf(address(this)) + totalReleased();
      uint256 owedToShares = (totalReceived * balanceOf(account)) / totalSupply();
      return owedToShares > _withheld[account] ? owedToShares - _withheld[account] : 0;

  }
}
