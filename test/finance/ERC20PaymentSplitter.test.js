const { constants, ether, expectEvent, send, expectRevert } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

const { expect } = require('chai');

const PaymentSplitter = artifacts.require('ERC20PaymentSplitter');
const ERC20 = artifacts.require('ERC20Mock');

contract('ERC20PaymentSplitter', function (accounts) {
  const [ owner, payee1, payee2, payee3, nonpayee1, payer1 ] = accounts;

  const amount = ether('1');

  beforeEach(async function () {
    this.token = await ERC20.new('MockToken', 'MT', payer1, ether('100'));
  });

  it('rejects an empty set of payees', async function () {
    await expectRevert(PaymentSplitter.new(this.token.address, [], []), 'PaymentSplitter: no payees');
  });

  it('rejects more payees than shares', async function () {
    await expectRevert(PaymentSplitter.new(this.token.address, [payee1, payee2, payee3], [20, 30]),
      'PaymentSplitter: payees and shares length mismatch',
    );
  });

  it('rejects more shares than payees', async function () {
    await expectRevert(PaymentSplitter.new(this.token.address, [payee1, payee2], [20, 30, 40]),
      'PaymentSplitter: payees and shares length mismatch',
    );
  });

  it('rejects null payees', async function () {
    await expectRevert(PaymentSplitter.new(this.token.address, [payee1, ZERO_ADDRESS], [20, 30]),
      'PaymentSplitter: account is the zero address',
    );
  });

  it('rejects zero-valued shares', async function () {
    await expectRevert(PaymentSplitter.new(this.token.address, [payee1, payee2], [20, 0]),
      'PaymentSplitter: shares are 0',
    );
  });

  it('rejects repeated payees', async function () {
    await expectRevert(PaymentSplitter.new(this.token.address, [payee1, payee1], [20, 30]),
      'PaymentSplitter: account already has shares',
    );
  });

  it('rejects an inexisting token', async function () {
    await expectRevert(PaymentSplitter.new(owner, [payee1, payee2], [20, 30]),
      'ERC20PaymentSplitter: token is not a contract',
    );
  });

  context('once deployed', function () {
    beforeEach(async function () {
      this.payees = [payee1, payee2, payee3];
      this.shares = [20, 10, 70];

      this.contract = await PaymentSplitter.new(this.token.address, this.payees, this.shares);
    });

    it('has total shares', async function () {
      expect(await this.contract.totalShares()).to.be.bignumber.equal('100');
    });

    it('has payees', async function () {
      await Promise.all(this.payees.map(async (payee, index) => {
        expect(await this.contract.payee(index)).to.equal(payee);
        expect(await this.contract.released(payee)).to.be.bignumber.equal('0');
      }));
    });

    it('rejects payments', async function () {
      await expectRevert.unspecified(send.ether(owner, this.contract.address, amount));
    });

    describe('shares', async function () {
      it('stores shares if address is payee', async function () {
        expect(await this.contract.shares(payee1)).to.be.bignumber.not.equal('0');
      });

      it('does not store shares if address is not payee', async function () {
        expect(await this.contract.shares(nonpayee1)).to.be.bignumber.equal('0');
      });
    });

    describe('release', async function () {
      it('reverts if no funds to claim', async function () {
        await expectRevert(this.contract.release(payee1),
          'PaymentSplitter: account is not due payment',
        );
      });
      it('reverts if non-payee want to claim', async function () {
        await this.token.transfer(this.contract.address, amount, { from: payer1 });
        await expectRevert(this.contract.release(nonpayee1),
          'PaymentSplitter: account has no shares',
        );
      });
    });

    it('distributes funds to payees', async function () {
      await this.token.transfer(this.contract.address, amount, { from: payer1 });

      // receive funds
      const initBalance = await this.token.balanceOf(this.contract.address);
      expect(initBalance).to.be.bignumber.equal(amount);

      // distribute to payees

      const initAmount1 = await this.token.balanceOf(payee1);
      const { logs: logs1 } = await this.contract.release(payee1, { gasPrice: 0 });
      const profit1 = (await this.token.balanceOf(payee1)).sub(initAmount1);
      expect(profit1).to.be.bignumber.equal(ether('0.20'));
      expectEvent.inLogs(logs1, 'PaymentReleased', { to: payee1, amount: profit1 });

      const initAmount2 = await this.token.balanceOf(payee2);
      const { logs: logs2 } = await this.contract.release(payee2, { gasPrice: 0 });
      const profit2 = (await this.token.balanceOf(payee2)).sub(initAmount2);
      expect(profit2).to.be.bignumber.equal(ether('0.10'));
      expectEvent.inLogs(logs2, 'PaymentReleased', { to: payee2, amount: profit2 });

      const initAmount3 = await this.token.balanceOf(payee3);
      const { logs: logs3 } = await this.contract.release(payee3, { gasPrice: 0 });
      const profit3 = (await this.token.balanceOf(payee3)).sub(initAmount3);
      expect(profit3).to.be.bignumber.equal(ether('0.70'));
      expectEvent.inLogs(logs3, 'PaymentReleased', { to: payee3, amount: profit3 });

      // end balance should be zero
      expect(await this.token.balanceOf(this.contract.address)).to.be.bignumber.equal('0');

      // check correct funds released accounting
      expect(await this.contract.totalReleased()).to.be.bignumber.equal(initBalance);
    });
  });
});
