const { BN, ether, expectEvent } = require('@openzeppelin/test-helpers');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');

const { expect } = require('chai');

const PaymentSplitter = artifacts.require('TokenizedETHSplitterMock');

contract('TokenizedETHSplitter', function (accounts) {
  const [ owner, payee1, payee2, payee3 ] = accounts;

  const amount = ether('1');

  beforeEach(async function () {
    this.contract = await PaymentSplitter.new();
  });

  it('set payee before receive', async function () {
    await this.contract.mint(payee1, 1);
    await web3.eth.sendTransaction({ from: owner, to: this.contract.address, value: amount });

    expectEvent(await this.contract.release(payee1), 'PaymentReleased', {
      to: payee1,
      amount: amount,
    });
    // await expectEvent.inTransaction(receipt.tx, this.token, 'Transfer', {
    //   from: this.contract.address,
    //   to: payee1,
    //   value: amount,
    // });
  });

  it('set payee after receive', async function () {
    await web3.eth.sendTransaction({ from: owner, to: this.contract.address, value: amount });
    await this.contract.mint(payee1, 1);

    expectEvent(await this.contract.release(payee1), 'PaymentReleased', {
      to: payee1,
      amount: amount,
    });
    // await expectEvent.inTransaction(receipt.tx, this.token, 'Transfer', {
    //   from: this.contract.address,
    //   to: payee1,
    //   value: amount,
    // });
  });

  it('multiple payees', async function () {
    await Promise.all(Object.entries({
      [payee1]: new BN(20),
      [payee2]: new BN(10),
      [payee3]: new BN(70),
    }).map(([ address, shares ]) => this.contract.mint(address, shares)));
    await web3.eth.sendTransaction({ from: owner, to: this.contract.address, value: amount });

    // distribute to payees
    for (const payee of [ payee1, payee2, payee3 ]) {
      const before = await web3.eth.getBalance(payee).then(balance => new BN(balance));
      const shares = await this.contract.balanceOf(payee);
      const supply = await this.contract.totalSupply();
      const profit = amount.mul(shares).div(supply);

      expectEvent(await this.contract.release(payee), 'PaymentReleased', {
        to: payee,
        amount: profit,
      });

      const after = await web3.eth.getBalance(payee).then(balance => new BN(balance));
      expect(after.sub(before)).to.be.bignumber.equal(profit);
    }

    // check correct funds released accounting
    expect(await web3.eth.getBalance(this.contract.address)).to.be.bignumber.equal('0');
  });

  it('multiple payees with varying shares', async function () {
    const manifest = {
      [payee1]: { shares: new BN(0), pending: new BN(0) },
      [payee2]: { shares: new BN(0), pending: new BN(0) },
      [payee3]: { shares: new BN(0), pending: new BN(0) },
    };
    const runCheck = () => Promise.all(Object.entries(manifest).map(async ([ account, { shares, pending } ]) => {
      expect(await this.contract.balanceOf(account)).to.be.bignumber.equal(shares);
      expect(await this.contract.pendingRelease(account)).to.be.bignumber.equal(pending);
    }));

    await runCheck();

    await this.contract.mint(payee1, '100');
    await this.contract.mint(payee2, '100');
    manifest[payee1].shares = manifest[payee1].shares.addn(100);
    manifest[payee2].shares = manifest[payee2].shares.addn(100);
    await runCheck();

    await web3.eth.sendTransaction({ from: owner, to: this.contract.address, value: 100 });
    manifest[payee1].pending = manifest[payee1].pending.addn(50);
    manifest[payee2].pending = manifest[payee2].pending.addn(50);
    await runCheck();

    await this.contract.mint(payee1, '100');
    await this.contract.mint(payee3, '100');
    manifest[payee1].shares = manifest[payee1].shares.addn(100);
    manifest[payee3].shares = manifest[payee3].shares.addn(100);
    await runCheck();

    await web3.eth.sendTransaction({ from: owner, to: this.contract.address, value: 100 });
    manifest[payee1].pending = manifest[payee1].pending.addn(50);
    manifest[payee2].pending = manifest[payee2].pending.addn(25);
    manifest[payee3].pending = manifest[payee3].pending.addn(25);
    await runCheck();

    await this.contract.burn(payee1, '200');
    manifest[payee1].shares = manifest[payee1].shares.subn(200);
    await runCheck();

    await web3.eth.sendTransaction({ from: owner, to: this.contract.address, value: 100 });
    manifest[payee2].pending = manifest[payee2].pending.addn(50);
    manifest[payee3].pending = manifest[payee3].pending.addn(50);
    await runCheck();

    await this.contract.transfer(payee3, '40', { from: payee2 });
    manifest[payee2].shares = manifest[payee2].shares.subn(40);
    manifest[payee3].shares = manifest[payee3].shares.addn(40);
    await runCheck();

    await web3.eth.sendTransaction({ from: owner, to: this.contract.address, value: 100 });
    manifest[payee2].pending = manifest[payee2].pending.addn(30);
    manifest[payee3].pending = manifest[payee3].pending.addn(70);
    await runCheck();

    for (const [ account, { pending }] of Object.entries(manifest)) {
      const before = await web3.eth.getBalance(account).then(balance => new BN(balance));

      expectEvent(await this.contract.release(account), 'PaymentReleased', { to: account, amount: pending });

      const after = await web3.eth.getBalance(account).then(balance => new BN(balance));
      expect(after.sub(before)).to.be.bignumber.equal(pending);
    }
  });
});
