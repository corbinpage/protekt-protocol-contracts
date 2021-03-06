pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/aave/ILendingPool.sol";

/**
 * @dev Extension of pToken that specifies how rewards are collected for
 * the Aave-USDC and sent to shieldToken. 
 */
contract HarvestRewardsAaveUsdcManualReferral {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Kovan
    // address public constant lendingPoolAddress = address(0xE0fBa4Fc209b4948668006B2bE61711b7f465bAe);
    // address public constant usdcTokenAddress = address(0xe22da380ee6B445bb8273C81944ADEB6E8450422);

    // Mainnet
    address public constant lendingPoolAddress = address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    address public constant usdcTokenAddress = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    uint256 shieldFee = 20;

    event HarvestRewards(uint256 amount);

    /**
     * @dev Collects rewards from deposited tokens and sends to the shieldToken
     */
    function harvestRewards(IERC20 depositToken, uint256 _balanceLastHarvest, address shieldTokenAddress) public {
      uint256 interest = depositToken.balanceOf(address(this)).sub(_balanceLastHarvest);        
      uint256 shieldInterest = interest.mul(shieldFee).div(100);
      uint256 keepInterest = interest.sub(shieldInterest);

      if(shieldInterest > 0) {
        depositToken.safeTransfer(shieldTokenAddress, shieldInterest);
      }

      emit HarvestRewards(interest);
    }

    /**
     * @dev Deposits coreTokens into Aave and returns underlyingTokens
     */
    function depositCoreTokens(uint256 _amount, address depositor) public returns (uint256) {
      // Bring in the amount from the depositor
      IERC20(usdcTokenAddress).safeTransferFrom(depositor, address(this), _amount);

      // Give approval to LendingPool to deposit the tokens
      IERC20(usdcTokenAddress).safeApprove(lendingPoolAddress, _amount);

      // LendingPool.deposit(address asset, uint256 amount, address onBehalfOf, uint16 shieldCode)
      ILendingPool(lendingPoolAddress).deposit(usdcTokenAddress, _amount, address(this), 0);

      return _amount;
    }
}