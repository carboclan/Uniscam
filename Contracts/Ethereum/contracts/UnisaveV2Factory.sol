pragma solidity =0.6.12;

import './interfaces/IUnisaveV2Factory.sol';
import './UnisaveV2Pair.sol';

contract UnisaveV2Factory is IUnisaveV2Factory {
    address public override feeTo;
    address public override feeToSetter;
    address public override migrator;
    address public override externality;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor() public {
        feeToSetter = msg.sender;
    }

    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(UnisaveV2Pair).creationCode);
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'UnisaveV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UnisaveV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UnisaveV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(UnisaveV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        UnisaveV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'UnisaveV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setMigrator(address _migrator) external override {
        require(msg.sender == feeToSetter, 'UnisaveV2: FORBIDDEN');
        migrator = _migrator;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'UnisaveV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setExternality(address _externality) external override {
        require(msg.sender == feeToSetter, 'UnisaveV2: FORBIDDEN');
        externality = _externality;
    }    

}
