pragma solidity 0.6.12;
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "./lib/SafeMathInt.sol";
import "./ERC20UpgradeSafe.sol";

contract R12BaseToken is ERC20UpgradeSafe, OwnableUpgradeSafe {
    using SafeMath for uint256;
    using SafeMathInt for int256;

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event LogMonetaryPolicyUpdated(address monetaryPolicy);
    event LogUserBanStatusUpdated(address user, bool banned);

    address public monetaryPolicy;

    modifier validRecipient(address to) {
        require(to != address(0x0));
        require(to != address(this));
        _;
    }

    uint256 private constant DECIMALS = 9;
    uint256 private constant MAX_UINT256 = ~uint256(0);
    uint256 private constant INITIAL_SUPPLY = 8_795_645 * 10**DECIMALS;
    uint256 private constant INITIAL_SHARES = (MAX_UINT256 / (10 ** 36)) - ((MAX_UINT256 / (10 ** 36)) % INITIAL_SUPPLY);
    uint256 private constant MAX_SUPPLY = ~uint128(0);  // (2^128) - 1

    uint256 private _totalShares;
    uint256 private _totalSupply;
    uint256 private _sharesPerBASE;
    mapping(address => uint256) private _shareBalances;

    mapping(address => bool) public bannedUsers;

    mapping (address => mapping (address => uint256)) private _allowedBASE;

    bool public transfersPaused;
    bool public rebasesPaused;

    mapping(address => bool) public transferPauseExemptList;

    function setTransfersPaused(bool _transfersPaused)
        public
        onlyOwner
    {
        transfersPaused = _transfersPaused;
    }

    function setTransferPauseExempt(address user, bool exempt)
        public
        onlyOwner
    {
        if (exempt) {
            transferPauseExemptList[user] = true;
        } else {
            delete transferPauseExemptList[user];
        }
    }

    function setRebasesPaused(bool _rebasesPaused)
        public
        onlyOwner
    {
        rebasesPaused = _rebasesPaused;
    }

  
    function setMonetaryPolicy(address monetaryPolicy_)
        external
        onlyOwner
    {
        monetaryPolicy = monetaryPolicy_;
        emit LogMonetaryPolicyUpdated(monetaryPolicy_);
    }

    function rebase(uint256 epoch, int256 supplyDelta)
        external
        returns (uint256)
    {
        require(msg.sender == monetaryPolicy, "only monetary policy");
        require(!rebasesPaused, "rebases paused");

        if (supplyDelta == 0) {
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        }

        if (supplyDelta < 0) {
            _totalSupply = _totalSupply.sub(uint256(supplyDelta.abs()));
        } else {
            _totalSupply = _totalSupply.add(uint256(supplyDelta));
        }

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _sharesPerBASE = _totalShares.div(_totalSupply);

        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    function totalShares()
        public
        view
        returns (uint256)
    {
        return _totalShares;
    }

    function sharesOf(address user)
        public
        view
        returns (uint256)
    {
        return _shareBalances[user];
    }

    function mintShares(address recipient, uint256 amount)
        public
    {
        require(msg.sender == monetaryPolicy, "forbidden");
        _shareBalances[recipient] = _shareBalances[recipient].add(amount);
        _totalShares = _totalShares.add(amount);
    }

    function burnShares(address recipient, uint256 amount)
        public
    {
        require(msg.sender == monetaryPolicy, "forbidden");
        require(_shareBalances[recipient] >= amount, "amount");
        _shareBalances[recipient] = _shareBalances[recipient].sub(amount);
        _totalShares = _totalShares.sub(amount);
    }

    function initialize()
        public
        initializer
    {
        __ERC20_init("R12Base Protocol", "R12BASE");
        _setupDecimals(uint8(DECIMALS));
        __Ownable_init();

        _totalShares = INITIAL_SHARES;
        _totalSupply = INITIAL_SUPPLY;
        _shareBalances[owner()] = _totalShares;
        _sharesPerBASE = _totalShares.div(_totalSupply);

        bannedUsers[0xeB31973E0FeBF3e3D7058234a5eBbAe1aB4B8c23] = true;

        emit Transfer(address(0x0), owner(), _totalSupply);
    }

    function setUserBanStatus(address user, bool banned)
        public
        onlyOwner
    {
        if (banned) {
            bannedUsers[user] = true;
        } else {
            delete bannedUsers[user];
        }
        emit LogUserBanStatusUpdated(user, banned);
    }

    function totalSupply()
        public
        override
        view
        returns (uint256)
    {
        return _totalSupply;
    }

    function balanceOf(address who)
        public
        override
        view
        returns (uint256)
    {
        return _shareBalances[who].div(_sharesPerBASE);
    }

    function transfer(address to, uint256 value)
        public
        override(ERC20UpgradeSafe)
        validRecipient(to)
        returns (bool)
    {
        require(bannedUsers[msg.sender] == false, "you are banned");
        require(!transfersPaused || transferPauseExemptList[msg.sender], "paused");

        uint256 shareValue = value.mul(_sharesPerBASE);
        _shareBalances[msg.sender] = _shareBalances[msg.sender].sub(shareValue);
        _shareBalances[to] = _shareBalances[to].add(shareValue);
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function allowance(address owner_, address spender)
        public
        override
        view
        returns (uint256)
    {
        return _allowedBASE[owner_][spender];
    }

    function transferFrom(address from, address to, uint256 value)
        public
        override
        validRecipient(to)
        returns (bool)
    {
        require(bannedUsers[msg.sender] == false, "you are banned");
        require(!transfersPaused || transferPauseExemptList[msg.sender], "paused");

        _allowedBASE[from][msg.sender] = _allowedBASE[from][msg.sender].sub(value);

        uint256 shareValue = value.mul(_sharesPerBASE);
        _shareBalances[from] = _shareBalances[from].sub(shareValue);
        _shareBalances[to] = _shareBalances[to].add(shareValue);
        emit Transfer(from, to, value);

        return true;
    }

    function approve(address spender, uint256 value)
        public
        override
        returns (bool)
    {
        require(!transfersPaused || transferPauseExemptList[msg.sender], "paused");

        _allowedBASE[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        override
        returns (bool)
    {
        require(!transfersPaused || transferPauseExemptList[msg.sender], "paused");

        _allowedBASE[msg.sender][spender] = _allowedBASE[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowedBASE[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        override
        returns (bool)
    {
        require(!transfersPaused || transferPauseExemptList[msg.sender], "paused");

        uint256 oldValue = _allowedBASE[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedBASE[msg.sender][spender] = 0;
        } else {
            _allowedBASE[msg.sender][spender] = oldValue.sub(subtractedValue);
        }
        emit Approval(msg.sender, spender, _allowedBASE[msg.sender][spender]);
        return true;
    }
}
