pragma solidity =0.6.12;

import './interfaces/IUnisaveV2Externality.sol';
import './interfaces/IUnisaveV2Factory.sol';
import './interfaces/IUnisaveV2Pair.sol';

contract UnisaveV2Externality is IUnisaveV2Externality {

    address public pancake_factory;

    constructor() public {
    }

    function getReserves(address tokenA, address tokenB) external override view returns (uint r0, uint r1) {
        address pair = IUnisaveV2Factory(pancake_factory).getPair(tokenA, tokenB);
        if (pair != address(0)) {
            (r0, r1, ) = IUnisaveV2Pair(pair).getReserves();
        }
    }
}
