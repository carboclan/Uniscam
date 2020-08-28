/**
 *Submitted for verification at Etherscan.io on 2020-02-01
*/

pragma solidity ^0.5.17;

pragma experimental ABIEncoderV2;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface ICrvDeposit {
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function balanceOf(address) external view returns (uint256);
    function claimable_tokens(address) external view returns (uint256);
}

interface ICrvMinter {
    function mint(address) external;
    function mint_for(address, address) external;
}

interface ICrvVoting {
    function increase_amount(uint256) external;
    function create_lock(uint256, uint256) external;
    function withdraw() external;
}

interface IUniswap {
    function swapExactTokensForTokens(uint, uint, address[] calldata, address, uint) external;
}

contract Context {
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 _totalSupply;
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "ERC20: burn amount exceeds allowance"));
    }
}

contract ERC20Detailed is IERC20 {
    string constant private _name = "yyCrv";
    string constant private _symbol = "yyCrv";
    uint8 constant private _decimals = 18;

    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

contract ReentrancyGuard {
    uint256 private _guardCounter;

    constructor () internal {
        _guardCounter = 1;
    }

    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "ReentrancyGuard: reentrant call");
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () internal {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }
    function owner() public view returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != 0x0 && codehash != accountHash);
    }
    function toPayable(address account) internal pure returns (address payable) {
        return address(uint160(account));
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-call-value
        (bool success, ) = recipient.call.value(amount)("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract yyCrv_test is ERC20, ERC20Detailed, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    uint256 public pool;
    uint8 public maximum_mining_ratio;
    uint8 public minimum_mining_ratio;    

    IERC20 constant public yCrv = IERC20(0xc778417E063141139Fce010982780140Aa0cD5Ab);  //IERC20(0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8);
    IERC20 constant public y3d = IERC20(0xc7fD9aE2cf8542D71186877e21107E1F3A0b55ef);
    IERC20 constant public CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address constant public WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant public crv_deposit = address(0xFA712EE4788C042e2B7BB55E6cb8ec569C4530c1);
    address constant public crv_minter = address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0);
    address constant public uniswap = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    ICrvVoting constant public crv_voting = ICrvVoting(0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2);
    address public crv_consul = address(0x6465F1250c9fe162602Db83791Fc3Fb202D70a7B);

    // Anti-front running fee
    uint16 public _default_fees = 100; // 10%
    mapping (address => uint16) _fees;
    mapping (address => uint) _stake_timestamp;
    uint public _fees_duration = 30 days;

    constructor () public {
        pool = 1; _mint(msg.sender, 1); // avoid div by 1
        yCrv.approve(crv_deposit, uint(-1));
//        CRV.approve(crv_consul, uint(-1));        
        maximum_mining_ratio = 95;
        minimum_mining_ratio = 70;
    }

    function() external payable {
    }

    function fee(address account) public view returns (uint) {
        if (_fees[account] == uint16(-1)) return 0;
        uint t = block.timestamp - _stake_timestamp[account];
        if (t >= _fees_duration) return 0;
        uint f = _fees[account]; if (f == 0) f = _default_fees;
        return f.mul(t).div(_fees_duration);
    }

    // Stake yCrv for yyCrv
    function stake(uint256 _amount) external {
        require(_amount > 0, "deposit must be greater than 0");
        yCrv.transferFrom(msg.sender, address(this), _amount);
        // invariant: shares/totalSupply = amount/pool
        uint256 shares = (_amount.mul(_totalSupply)).div(pool);
        pool += _amount; _mint(msg.sender, shares);
        if (_fees[msg.sender] != uint16(-1)) _stake_timestamp[msg.sender] = block.timestamp;
    }

    // Unstake yyCrv for yCrv
    function unstake(uint256 _shares) external nonReentrant {
        require(_shares > 0, "deposit must be greater than 0");        
        // invariant: shres/totalSupply = amount/pool
        uint256 _amount = (pool.mul(_shares)).div(_totalSupply);
        _burn(msg.sender, _shares); pool -= _amount;                
        _amount = _amount.sub(_amount.mul(fee(msg.sender)).div(1000));
        uint256 b = yCrv.balanceOf(address(this));
        if (b < _amount) withdraw(_amount - b);
        yCrv.transfer(msg.sender, _amount);
    }    

    function make_profit_internal(uint256 _amount) internal {
        require(_amount > 0, "deposit must be greater than 0");
        pool += _amount;
    }    

    function make_profit_external(uint256 _amount) public {
        make_profit_internal(_amount);
        yCrv.transferFrom(msg.sender, address(this), _amount);
    }

    function deposit_all() external {
        require(y3d.balanceOf(address(msg.sender)) >= 1e16, "0.01 y3d requirement");
        ICrvDeposit(crv_deposit).deposit(yCrv.balanceOf(address(this)));
    }

    function deposit() external {
        require(y3d.balanceOf(address(msg.sender)) >= 1e15, "0.001 y3d requirement");
        uint a = yCrv.balanceOf(address(this));
        uint b = ICrvDeposit(crv_deposit).balanceOf(address(this));
        uint t = a + b; t = t.mul(maximum_mining_ratio).div(100);
        require (t > b, "enough miners");
        if (t > b) ICrvDeposit(crv_deposit).deposit(t - b);        
    }

    function harvest_to_consul() external {
        ICrvMinter(crv_minter).mint_for(crv_deposit, crv_consul);
    }

    function harvest_to_uniswap() external {
        require(y3d.balanceOf(address(msg.sender)) >= 1e17, "0.1 y3d requirement");

        ICrvMinter(crv_minter).mint(crv_deposit);
        uint _crv = CRV.balanceOf(address(this));
        uint yCrv_before_swap = yCrv.balanceOf(address(this));

        require(_crv > 0, "no enough Crv to be swap");

        CRV.safeApprove(uniswap, 0);
        CRV.safeApprove(uniswap, _crv);            
        address[] memory path = new address[](3);
        path[0] = 0xD533a949740bb3306d119CC777fa900bA034cd52; // CRV
        path[1] = WETH;
        path[2] = 0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8; // yCrv;      
        IUniswap(uniswap).swapExactTokensForTokens(_crv, uint(0), path, address(this), now.add(1800));

        uint yCrv_delta = yCrv.balanceOf(address(this)).sub(yCrv_before_swap);
        make_profit_internal(yCrv_delta);        
    }

    function withdraw(uint256 _amount) internal {
        ICrvDeposit(crv_deposit).withdraw(_amount);
    }

    // Todo(minakokojima): consul should be a contract, automatic buy in and burn Y3D.
    function change_crv_consul(address new_consul) public {
        require(msg.sender == crv_consul, 'only current consul');
        crv_consul = new_consul;        
        CRV.approve(crv_consul, uint(-1));
    }

    /* veCRV Booster */
}