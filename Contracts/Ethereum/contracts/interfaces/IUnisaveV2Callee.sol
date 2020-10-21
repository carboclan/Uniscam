pragma solidity =0.6.12;

interface IUnisaveV2Callee {
    function UnisaveV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
