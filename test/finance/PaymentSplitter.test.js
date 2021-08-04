const { BN, balance, ether, expectEvent, send, expectRevert } = require('@openzeppelin/test-helpers');

const { expect } = require('chai');

const PaymentSplitter = artifacts.require('PaymentSplitter');

contract('PaymentSplitter', function (accounts) {
  const [ owner, payee1, payee2, payee3, nonpayee1, payer1 ] = accounts;

  const amount = ether('1');

  it('rejects an empty set of payees', async function () {
    await expectRevert(PaymentSplitter.new([], []), 'PaymentSplitter: no payees');
  });

  it('rejects more payees than shares', async function () {
    await expectRevert(PaymentSplitter.new([payee1, payee2, payee3], [20, 30]),
      'PaymentSplitter: payees and shares length mismatch',
    );
  });

  it('rejects more shares than payees', async function () {
    await expectRevert(PaymentSplitter.new([payee1, payee2], [20, 30, 40]),
      'PaymentSplitter: payees and shares length mismatch',
    );
  });

  context('once deployed', function () {
    beforeEach(async function () {
      this.payees = {
        [payee1]: new BN(20),
        [payee2]: new BN(10),
        [payee3]: new BN(70),
      };

      this.totalShares = Object.values(this.payees).reduce((a, b) => a.add(b), new BN(0));

      this.contract = await PaymentSplitter.new(
        Object.keys(this.payees),
        Object.values(this.payees),
      );
    });

    it('has total shares', async function () {
      expect(await this.contract.totalShares()).to.be.bignumber.equal(this.totalShares);
    });

    it('has payees', async function () {
      await Promise.all(Object.entries(this.payees).map(async ([ address, shares ]) => {
        expect(await this.contract.shares(address)).to.be.bignumber.equal(shares);
        expect(await this.contract.released(address)).to.be.bignumber.equal('0');
      }));
    });

    it('accepts payments', async function () {
      await send.ether(owner, this.contract.address, amount);

      expect(await balance.current(this.contract.address)).to.be.bignumber.equal(amount);
    });

    describe('shares', async function () {
      it('stores shares if address is payee', async function () {
        expect(await this.contract.shares(payee1)).to.be.bignumber.not.equal('0');
      });

      it('empty shares if address is not payee', async function () {
        expect(await this.contract.shares(nonpayee1)).to.be.bignumber.equal('0');
      });
    });

    describe('release', async function () {
      it('no funds to claim', async function () {
        const { logs } = await this.contract.release(nonpayee1);
        expect(logs).to.be.deep.equal([]);
      });
    });

    it('distributes funds to payees', async function () {
      await send.ether(payer1, this.contract.address, amount);

      // receive funds
      const initBalance = await balance.current(this.contract.address);
      expect(initBalance).to.be.bignumber.equal(amount);

      // distribute to payees
      for (const [ address, shares ] of Object.entries(this.payees)) {
        const before = await balance.current(address);
        const { receipt } = await this.contract.release(address, { gasPrice: 0 });
        const profit = (await balance.current(address)).sub(before);
        expect(profit).to.be.bignumber.equal(amount.mul(shares).div(this.totalShares));
        expectEvent(receipt, 'PaymentReleased', {
          to: address,
          amount: profit,
        });
      }

      // end balance should be zero
      expect(await balance.current(this.contract.address)).to.be.bignumber.equal('0');

      // check correct funds released accounting
      expect(await this.contract.totalReleased()).to.be.bignumber.equal(initBalance);
    });
  });
});
