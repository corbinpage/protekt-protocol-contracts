pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./helpers/HarvestRewardsAaveUsdcManual.sol";
import "../claimsManagers/interfaces/IClaimsManagerCore.sol";

contract pTokenAave is
    ERC20,
    ERC20Detailed,
    HarvestRewardsAaveUsdcManual,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    IERC20 public depositToken;
    address public shieldTokenAddress;

    address public feeModel;
    address public governance;
    IClaimsManagerCore public claimsManager;
    bool public isCapped;
    uint256 public maxDeposit;

    uint256 public balanceLastHarvest;

    constructor(address _depositToken, address _feeModel, address _claimsManager)
        public
        ERC20Detailed(
            string(abi.encodePacked("protekt ", ERC20Detailed(_depositToken).name())),
            string(abi.encodePacked("p", ERC20Detailed(_depositToken).symbol())),
            ERC20Detailed(_depositToken).decimals()
        )
        ReentrancyGuard()
    {
        depositToken = IERC20(_depositToken);
        feeModel = _feeModel;
        claimsManager = IClaimsManagerCore(_claimsManager);
        governance = msg.sender;
        isCapped = false;
    }

    function balance() public view returns (uint256) {
        return depositToken.balanceOf(address(this));
    }
    
    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setShieldToken(address _shieldTokenAddress) public {
        require(msg.sender == governance, "!governance");
        shieldTokenAddress = _shieldTokenAddress;
    }

    function depositCoreTokens(uint256 _amount) nonReentrant() public {
        require(claimsManager.isReady(),'!Ready');
        
        harvestRewards(); // - does this need to be here? will just increase gas

        uint256 _before = depositToken.balanceOf(address(this));
        
        // Deposit coreTokens into Aave and then deposit underlyingTokens into pToken
        uint256 _after = super.depositCoreTokens(_amount, msg.sender);

        _deposit(_after,_before,msg.sender);
    }

    function depositAll() external {
        deposit(depositToken.balanceOf(msg.sender));
    }

    function deposit(uint256 _amount) nonReentrant() public {
        // Rewards are harvested for the current block before deposit
        harvestRewards();

        _deposit(_amount);
    }

     function _deposit(uint256 _after, uint256 _before, address depositor) internal {
        if(isCapped){
            require(_after <= maxDeposit,"Cap exceeded");
        }
        uint256 _pool = balance();
        uint256 _amount = _after.sub(_before);
        
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(depositor, shares);
    }


    function _deposit(uint256 _amount) internal {
        require(claimsManager.isReady(),'!Ready');
        uint256 _pool = balance();
        uint256 _before = depositToken.balanceOf(address(this));
        if(isCapped){
            require((_before + _amount) <= maxDeposit,"Cap exceeded");
        }
        depositToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = depositToken.balanceOf(address(this));
        _amount = _after.sub(_before); // Additional check for deflationary depositTokens
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
        balanceLastHarvest = balance();
    }

    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    function harvestRewards() public {
        super.harvestRewards(depositToken,shieldTokenAddress,balanceLastHarvest);
    }

    function withdraw(uint256 _shares) nonReentrant() public  {
        // Rewards are harvested for the current block before withdrawal
        harvestRewards();

        uint256 r = (balance().mul(_shares)).div(totalSupply());
        _burn(msg.sender, _shares);

        depositToken.safeTransfer(msg.sender, r);
        balanceLastHarvest = balance();
    }

    // Returns depositTokens per share price
    function getPricePerFullShare() public view returns (uint256) {
        return balance().mul(1e18).div(totalSupply());
    }


    // cap contract at a set amount
    function capDeposits(uint _amount) external {
        require(msg.sender == governance, "!governance");
        // uint256 _currentBalance = depositToken.balanceOf(address(this));
        // require(_amount < _currentBalance, "Cap exceeds current balance");
        isCapped = true;
        maxDeposit = _amount;
    }

    // uncap contract
    function uncapDeposits() external {
        require(msg.sender == governance, "!governance");
        isCapped = false;
    }

}