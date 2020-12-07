pragma solidity =0.6.12;

import './UnisaveV2ERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IyToken.sol';
import './interfaces/IUnisaveV2Factory.sol';
import './interfaces/IUnisaveV2Callee.sol';

contract UnisaveV2Pair is UnisaveV2ERC20 {
    using SafeMathUnisave for uint;
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR_APPROVE = 0x095ea7b3;
    bytes4 private constant SELECTOR_TRANSFER = 0xa9059cbb; 

    address public factory;
    address public token0;
    address public token1;
    address public yToken0;
    address public yToken1;
    uint16 redepositRatio0;
    uint16 redepositRatio1;
    uint public deposited0;
    uint public deposited1;
    uint112 public dummy0;
    uint112 public dummy1;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint16 public fee = 30;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'UnisaveV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view returns (address) {
        return IUnisaveV2Factory(factory).feeTo();
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function getDeposited() public view returns (uint _deposited0, uint _deposited1) {
        _deposited0 = deposited0;
        _deposited1 = deposited1;
    }

    function getDummy() public view returns (uint _dummy0, uint _dummy1) {
        _dummy0 = dummy0;
        _dummy1 = dummy1;
    }

    function _safeApprove(address token, address spender, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR_APPROVE, spender, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'SAFE_APPROVE_FAILED');
    }

    function _safeTransfer(address token, address to, uint value) private {
        IERC20 u = IERC20(token);
        uint b = u.balanceOf(address(this));
        if (b < value) {
            if (token == token0) {
                _withdrawAll0();
                (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR_TRANSFER, to, value));             
                if (redepositRatio0 > 0) {
                    redeposit0();
                }
                require(success && (data.length == 0 || abi.decode(data, (bool))), 'UnisaveV2: TRANSFER_FAILED');
            } else {
                _withdrawAll1();
                (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR_TRANSFER, to, value));   
                if (redepositRatio1 > 0) {
                    redeposit1();
                }
                require(success && (data.length == 0 || abi.decode(data, (bool))), 'UnisaveV2: TRANSFER_FAILED');
            }
        } else {
            (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR_TRANSFER, to, value));   
            require(success && (data.length == 0 || abi.decode(data, (bool))), 'UnisaveV2: TRANSFER_FAILED');
        }
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event DummyMint(uint amount0, uint amount1);
    event DummyBurn(uint amount0, uint amount1);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    event FeeUpdated(uint16 fee);

    event Y0Updated(address indexed token);
    event Y1Updated(address indexed token);

    event Deposited0Updated(uint deposited);
    event Deposited1Updated(uint deposited);

    event RedepositRatio0Updated(uint16 ratio);
    event RedepositRatio1Updated(uint16 ratio);

    constructor() public {
        factory = msg.sender;
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

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = b0();
        uint balance1 = b1();
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);
        _reserve0 -= dummy0;
        _reserve1 -= dummy1;
        uint _totalSupply = totalSupply; // gas savings
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);
        _reserve0 += dummy0;
        _reserve1 += dummy1;
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = b0().sub(dummy0);
        uint balance1 = b1().sub(dummy1);
        uint liquidity = balanceOf[address(this)];

        uint _totalSupply = totalSupply; // gas savings
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'UnisaveV2: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = b0();
        balance1 = b1();

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function dummy_mint(uint amount0, uint amount1) external onlyOwner() lock {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        dummy0 += uint112(amount0);
        dummy1 += uint112(amount1);
        emit DummyMint(amount0, amount1);
        _update(b0(), b1(), _reserve0, _reserve1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function dummy_burn(uint amount0, uint amount1) external onlyOwner() lock {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        dummy0 -= uint112(amount0);
        dummy1 -= uint112(amount1);
        emit DummyBurn(amount0, amount1);
        _update(b0(), b1(), _reserve0, _reserve1);
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
        uint balance0Adjusted = balance0.mul(10000).sub(amount0In.mul(fee));
        uint balance1Adjusted = balance1.mul(10000).sub(amount1In.mul(fee));
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(10000**2), 'UnisaveV2: K');
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

    function setFee(uint16 _fee) external onlyOwner() {
        fee = _fee;

        emit FeeUpdated(_fee);
    }

    // vault
    function b0() public view returns (uint b) {
        IERC20 u = IERC20(token0);
        b = u.balanceOf(address(this)).add(deposited0).add(dummy0);
    }
    function b1() public view returns (uint b) {
        IERC20 u = IERC20(token1);
        b = u.balanceOf(address(this)).add(deposited1).add(dummy1);
    }
    function approve0() public onlyOwner() {
        _safeApprove(token0, yToken0, uint(-1));
    }
    function approve1() public onlyOwner() {
        _safeApprove(token1, yToken1, uint(-1));

    }
    function unapprove0() public onlyOwner() {
        _safeApprove(token0, yToken0, 0);
    }
    function unapprove1() public onlyOwner() {
        _safeApprove(token1, yToken1, 0);
    }
    function setY0(address y) public onlyOwner() {
        yToken0 = y;
        emit Y0Updated(y);
        approve0();
    }
    function setY1(address y) public onlyOwner() {
        yToken1 = y;
        emit Y1Updated(y);
        approve1();
    }

    function deposit0(uint a) internal {
        require(a > 0, "deposit amount must be greater than 0");
        IyToken y = IyToken(yToken0);
        deposited0 += a;
        emit Deposited0Updated(deposited0);
        y.deposit(a);
    }
    function deposit1(uint a) internal {
        require(a > 0, "deposit amount must be greater than 0");
        IyToken y = IyToken(yToken1);
        deposited1 += a;
        emit Deposited1Updated(deposited1);
        y.deposit(a);
    }
    function depositSome0(uint a) onlyOwner() external {
        deposit0(a);
    }
    function depositSome1(uint a) onlyOwner() external {
        deposit1(a);
    }
    function depositAll0() onlyOwner() external {
        IERC20 u = IERC20(token0);
        deposit0(u.balanceOf(address(this)));
    }
    function depositAll1() onlyOwner() external {
        IERC20 u = IERC20(token1);
        deposit1(u.balanceOf(address(this)));
    }
    function redeposit0() internal {
        IERC20 u = IERC20(token0);
        deposit0(u.balanceOf(address(this)).mul(redepositRatio0).div(1000));
    }
    function redeposit1() internal {
        IERC20 u = IERC20(token1);
        deposit1(u.balanceOf(address(this)).mul(redepositRatio1).div(1000));
    }
    function set_redepositRatio0(uint16 _redpositRatio0) onlyOwner() external {
        require(_redpositRatio0 <= 1000, "ratio too large");
        redepositRatio0 = _redpositRatio0;

        emit RedepositRatio0Updated(_redpositRatio0);
    }
    function set_redepositRatio1(uint16 _redpositRatio1) onlyOwner() external {
        require(_redpositRatio1 <= 1000, "ratio too large");
        redepositRatio1 = _redpositRatio1;

        emit RedepositRatio1Updated(_redpositRatio1);
    }
    function _withdraw0(uint s) internal {
        require(s > 0, "withdraw amount must be greater than 0");
        IERC20 u = IERC20(token0);
        uint delta = u.balanceOf(address(this));
        IyToken y = IyToken(yToken0);
        y.withdraw(s);
        delta = u.balanceOf(address(this)).sub(delta);
        if (delta <= deposited0) {
            deposited0 -= delta;
        } else {
            delta -= deposited0; deposited0 = 0;
            _safeTransfer(token0, owner(), delta);
        }

        emit Deposited0Updated(deposited0);
    }
    function _withdraw1(uint s) internal {
        require(s > 0, "withdraw amount must be greater than 0");
        IERC20 u = IERC20(token1);
        uint delta = u.balanceOf(address(this));
        IyToken y = IyToken(yToken1);
        y.withdraw(s);
        delta = u.balanceOf(address(this)).sub(delta);
        if (delta <= deposited1) {
            deposited1 -= delta;
        } else {
            delta -= deposited1; deposited1 = 0;
            _safeTransfer(token1, owner(), delta);
        }

        emit Deposited1Updated(deposited1);
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
}
