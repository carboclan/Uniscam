// Dependency file: contracts/interfaces/IUnisaveV2Externality.sol

// pragma solidity =0.6.12;

interface IUnisaveV2Externality {
    function getReserves(address tokenA, address tokenB) external view returns (uint, uint);
}

// Dependency file: contracts/interfaces/IUnisaveV2Factory.sol

// pragma solidity =0.6.12;

interface IUnisaveV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}


// Dependency file: contracts/interfaces/IUnisaveV2Pair.sol

// pragma solidity =0.6.12;

interface IUnisaveV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function getDeposited() external view returns (uint _deposited0, uint _deposited1);
    function getDummy() external view returns (uint _dummy0, uint _dummy1);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);
    function getFee(address) external view returns (uint16);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function b0() external view returns (uint b);
    function b1() external view returns (uint b);

    function initialize(address, address) external;
}

// Root file: contracts/UnisaveV2Externality.sol

pragma solidity =0.6.12;

// import 'contracts/interfaces/IUnisaveV2Externality.sol';
// import 'contracts/interfaces/IUnisaveV2Factory.sol';
// import 'contracts/interfaces/IUnisaveV2Pair.sol';

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
