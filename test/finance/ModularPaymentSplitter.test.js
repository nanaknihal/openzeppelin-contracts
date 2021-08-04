const { BN, ether, expectEvent } = require('@openzeppelin/test-helpers');

const { expect } = require('chai');

const PaymentSplitter = artifacts.require('TokenSplitterMock');
const ERC20 = artifacts.require('ERC20Mock');

contract('TokenSplitter', function (accounts) {
  const [ owner, payee1, payee2, payee3 ] = accounts;

  const amount = ether('1');

  beforeEach(async function () {
    this.token = await ERC20.new('MockToken', 'MT', owner, ether('100'));
    this.contract = await PaymentSplitter.new(this.token.address);
  });

  it('set payee before receive', async function () {
    await this.contract.mint(payee1, 1);
    await this.token.transfer(this.contract.address, amount, { from: owner });

    expect(await this.contract.pendingRelease(payee1)).to.be.bignumber.equal(amount);

    const receipt = await this.contract.release(payee1);
    expectEvent(receipt, 'PaymentReleased', {
      to: payee1,
      amount: amount,
    });
    await expectEvent.inTransaction(receipt.tx, this.token, 'Transfer', {
      from: this.contract.address,
      to: payee1,
      value: amount,
    });

    expect(await this.contract.pendingRelease(payee1)).to.be.bignumber.equal('0');
  });

  it('set payee after receive', async function () {
    await this.token.transfer(this.contract.address, amount, { from: owner });
    await this.contract.mint(payee1, 1);

    expect(await this.contract.pendingRelease(payee1)).to.be.bignumber.equal(amount);

    const receipt = await this.contract.release(payee1);
    expectEvent(receipt, 'PaymentReleased', {
      to: payee1,
      amount: amount,
    });
    await expectEvent.inTransaction(receipt.tx, this.token, 'Transfer', {
      from: this.contract.address,
      to: payee1,
      value: amount,
    });

    expect(await this.contract.pendingRelease(payee1)).to.be.bignumber.equal('0');
  });

  it('multiple payees', async function () {
    await Promise.all(Object.entries({
      [payee1]: new BN(20),
      [payee2]: new BN(10),
      [payee3]: new BN(70),
    }).map(([ address, shares ]) => this.contract.mint(address, shares)));
    await this.token.transfer(this.contract.address, amount, { from: owner });

    const initBalance = await this.token.balanceOf(this.contract.address);
    expect(initBalance).to.be.bignumber.equal(amount);

    // distribute to payees
    for (const payee of [ payee1, payee2, payee3 ]) {
      const before = await this.token.balanceOf(payee);
      const shares = await this.contract.balanceOf(payee);
      const supply = await this.contract.totalSupply();
      const profit = amount.mul(shares).div(supply);

      const receipt = await this.contract.release(payee);
      expect((await this.token.balanceOf(payee)).sub(before)).to.be.bignumber.equal(profit);
      expectEvent(receipt, 'PaymentReleased', {
        to: payee,
        amount: profit,
      });
      await expectEvent.inTransaction(receipt.tx, this.token, 'Transfer', {
        from: this.contract.address,
        to: payee,
        value: profit,
      });
    }

    // check correct funds released accounting
    expect(await this.token.balanceOf(this.contract.address)).to.be.bignumber.equal('0');
    expect(await this.contract.totalReleased()).to.be.bignumber.equal(initBalance);
  });

  it('multiple payees with varying shares', async function () {
    this.skip();
  });
});
