pragma solidity =0.6.12;

import './UnisaveV2ERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IyToken.sol';
import './interfaces/IUnisaveV2Factory.sol';
import './interfaces/IUnisaveV2Callee.sol';

interface IMigrator {
    // Return the desired amount of liquidity token that the migrator wants.
    function desiredLiquidity() external view returns (uint256);
}

contract Ownable {

    address public _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }     
}

contract UnisaveV2Pair is UnisaveV2ERC20, Ownable {
    using SafeMathUnisave for uint;
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public token0;
    address public token1;
    address public yToken0;
    address public yToken1;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event
    uint8 public fee = 3;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'UnisaveV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        IERC20 u = IERC20(token);
        uint b = u.balanceOf(address(this));
        if (b < value) {
            if (token == token0) _withdrawAll0();
            else _withdrawAll1();
        }
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UnisaveV2: TRANSFER_FAILED');
    }

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

    constructor() public {
        factory = msg.sender;
        _owner = tx.origin;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UnisaveV2: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'UnisaveV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUnisaveV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = b0();
        uint balance1 = b1();
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            address migrator = IUnisaveV2Factory(factory).migrator();
            if (msg.sender == migrator) {
                liquidity = IMigrator(migrator).desiredLiquidity();
                require(liquidity > 0 && liquidity != uint256(-1), "Bad desired liquidity");
            } else {
                require(migrator == address(0), "Must not have migrator");
                liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
                _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
            }
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'UnisaveV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = b0();
        uint balance1 = b1();
        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'UnisaveV2: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = b0();
        balance1 = b1();

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'UnisaveV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UnisaveV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'UnisaveV2: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IUnisaveV2Callee(to).UnisaveV2Call(msg.sender, amount0Out, amount1Out, data);
        balance0 = b0();
        balance1 = b1();
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UnisaveV2: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(fee));
        uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(fee));
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UnisaveV2: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, b0().sub(reserve0));
        _safeTransfer(_token1, to, b1().sub(reserve1));
    }

    // force reserves to match balances
    function sync() external lock {
        _update(b0(), b1(), reserve0, reserve1);
    }

    function setFee(uint8 _fee) external onlyOwner() {
        fee = _fee;
    }

    // vault    
    function b0() public view returns (uint b) {
        IERC20 u = IERC20(token0);
        b = u.balanceOf(address(this));
        if (yToken0 != address(0)) {
            IyToken y = IyToken(yToken0);   
            b = b.add(y.balance().mul(y.balanceOf(address(this))).div(y.totalSupply()));
        }
    }
    function b1() public view returns (uint b) {
        IERC20 u = IERC20(token1);
        b = u.balanceOf(address(this));
        if (yToken1 != address(0)) {
            IyToken y = IyToken(yToken1);   
            b = b.add(y.balance().mul(y.balanceOf(address(this))).div(y.totalSupply()));
        }
    }    
    function approve0() public onlyOwner() {
        IERC20(token0).approve(yToken0, uint(-1));
    }
    function approve1() public onlyOwner() {
        IERC20(token1).approve(yToken1, uint(-1));
    }
    function unapprove0() public onlyOwner() {
        IERC20(token0).approve(yToken0, 0);
    }
    function unapprove1() public onlyOwner() {
        IERC20(token1).approve(yToken1, 0);
    }
    function setY0(address y) public onlyOwner() {
        yToken0 = y; 
        approve0();
    }
    function setY1(address y) public onlyOwner() {
        yToken1 = y;
        approve1();
    }
    function deposit0(uint a) onlyOwner() public {
        require(a > 0, "deposit amount must be greater than 0");
        IyToken y = IyToken(yToken0);
        y.deposit(a);
    }
    function deposit1(uint a) onlyOwner() public {
        require(a > 0, "deposit amount must be greater than 0");
        IyToken y = IyToken(yToken1);
        y.deposit(a);
    }    
    function depositAll0() onlyOwner() public {
        IERC20 u = IERC20(token0);
        deposit0(u.balanceOf(address(this)));
    }
    function depositAll1() onlyOwner() public {
        IERC20 u = IERC20(token1);
        deposit1(u.balanceOf(address(this)));
    }    
    function _withdraw0(uint s) internal {
        require(s > 0, "withdraw amount must be greater than 0");
        IyToken y = IyToken(yToken0);
        y.withdraw(s);
    }
    function _withdraw1(uint s) internal {
        require(s > 0, "withdraw amount must be greater than 0");
        IyToken y = IyToken(yToken1);
        y.withdraw(s);
    }    
    function _withdrawAll0() internal {
        IERC20 y = IERC20(yToken0);
        _withdraw0(y.balanceOf(address(this)));
    }
    function _withdrawAll1() internal {
        IERC20 y = IERC20(yToken1);
        _withdraw1(y.balanceOf(address(this)));
    }
    function withdraw0(uint s) external onlyOwner() {
        _withdraw0(s);
    }
    function withdraw1(uint s) external onlyOwner() {
        _withdraw1(s);
    }
    function withdrawAll0() external onlyOwner() {
        _withdrawAll0();
    }
    function withdrawAll1() external onlyOwner() {
        _withdrawAll1();
    }
    function resetOwnership(address newOwner) external virtual {
        address feeToSetter = IUnisaveV2Factory(factory).feeToSetter();
        require(msg.sender == feeToSetter, "only feeToSetter");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }     
}
