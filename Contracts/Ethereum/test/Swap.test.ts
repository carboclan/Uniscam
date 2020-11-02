import {expect, use} from 'chai';
import {Contract} from 'ethers';
import {deployContract, MockProvider, solidity} from 'ethereum-waffle';
import WETH9 from "../build/WETH9.json";
import Factory from '../build/UnisaveV2Factory.json';
import Router from '../build/UnisaveV2Router02.json';

use(solidity);

describe('Deploy Factory', () => {
  const [wallet, walletTo] = new MockProvider().getWallets();
  let wrappedEth: Contract;
  let factory: Contract;
  let router: Contract;

  beforeEach(async () => {
    wrappedEth = await deployContract(wallet, WETH9);
    factory = await deployContract(wallet, Factory);
    // router = await deployContract(wallet, Router, [ factory.address, wrappedEth.address ]);
  });


  it('Good to deploy a Router', async () => {
    console.info(`Factory: ${factory.address} WETH: ${wrappedEth.address}`)
    router = await deployContract(wallet, Router, [ factory.address, wrappedEth.address ]);
    expect(await router.factory()).to.equal(factory.address);
  });


  it('initial feeToSetter is me', async () => {
    expect(await factory.feeToSetter()).to.equal(wallet.address);
  });

  it('initial feeTo is me', async () => {
    expect(await factory.feeTo()).to.equal(wallet.address);
  });

  it('No Pair in the factory', async () => {
    expect(await factory.allPairsLength()).to.equal(0);
  });
});



// describe('Deploy Factory', () => {
//   const [wallet, walletTo] = new MockProvider().getWallets();
//   let token: Contract;

//   beforeEach(async () => {
//     token = await deployContract(wallet, Factory);
//   });

//   it('Transfer adds amount to destination account', async () => {
//     await token.transfer(walletTo.address, 7);
//     expect(await token.balanceOf(walletTo.address)).to.equal(7);
//   });

//   it('Transfer emits event', async () => {
//     await expect(token.transfer(walletTo.address, 7))
//       .to.emit(token, 'Transfer')
//       .withArgs(wallet.address, walletTo.address, 7);
//   });

//   it('Can not transfer above the amount', async () => {
//     await expect(token.transfer(walletTo.address, 1007)).to.be.reverted;
//   });

//   it('Can not transfer from empty account', async () => {
//     const tokenFromOtherWallet = token.connect(walletTo);
//     await expect(tokenFromOtherWallet.transfer(wallet.address, 1))
//       .to.be.reverted;
//   });

//   it('Calls totalSupply on BasicToken contract', async () => {
//     await token.totalSupply();
//     expect('totalSupply').to.be.calledOnContract(token);
//   });

//   it('Calls balanceOf with sender address on BasicToken contract', async () => {
//     await token.balanceOf(wallet.address);
//     expect('balanceOf').to.be.calledOnContractWith(token, [wallet.address]);
//   });
// });
