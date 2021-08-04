const { balance, constants, ether, expectEvent, send, expectRevert } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

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

  it('rejects null payees', async function () {
    await expectRevert(PaymentSplitter.new([payee1, ZERO_ADDRESS], [20, 30]),
      'PaymentSplitter: account is the zero address',
    );
  });

  it('rejects zero-valued shares', async function () {
    await expectRevert(PaymentSplitter.new([payee1, payee2], [20, 0]),
      'PaymentSplitter: shares are 0',
    );
  });

  it('rejects repeated payees', async function () {
    await expectRevert(PaymentSplitter.new([payee1, payee1], [20, 30]),
      'PaymentSplitter: account already has shares',
    );
  });

  context('once deployed', function () {
    beforeEach(async function () {
      this.payees = [payee1, payee2, payee3];
      this.shares = [20, 10, 70];

      this.contract = await PaymentSplitter.new(this.payees, this.shares);
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

    it('accepts payments', async function () {
      await send.ether(owner, this.contract.address, amount);

      expect(await balance.current(this.contract.address)).to.be.bignumber.equal(amount);
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
        await send.ether(payer1, this.contract.address, amount);
        await expectRevert(this.contract.release(nonpayee1),
          'PaymentSplitter: account has no shares',
        );
      });
    });

    it('distributes funds to payees', async function () {
      await send.ether(payer1, this.contract.address, amount);

      // receive funds
      const initBalance = await balance.current(this.contract.address);
      expect(initBalance).to.be.bignumber.equal(amount);

      // distribute to payees
      for (const payee of [ payee1, payee2, payee3 ]) {
        const before = await balance.current(payee);
        const shares = await this.contract.shares(payee);
        const supply = await this.contract.totalShares();
        const profit = amount.mul(shares).div(supply);

        const receipt = await this.contract.release(payee);
        expect((await balance.current(payee)).sub(before)).to.be.bignumber.equal(profit);
        expectEvent(receipt, 'PaymentReleased', {
          to: payee,
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
