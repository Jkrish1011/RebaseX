// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
* @title RebaseXToken
* @author Jayakrishnan Ashok
* @notice A Cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
* @notice The interest rate in the smart contract can only decrease.
* @notice Each user will have their own interest rate that is the global interest rate at the time they mint the token.
*/
contract RebaseXToken is ERC20, Ownable, AccessControl {
    // -------------- ERRORS -------------- 

    error RebaseXToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    // -------------- STATE VARIABLES -------------- 

    // State variable to keep track of user's interest rates
    mapping(address => uint256) private s_userInterestRate;
    // State variable to keep track of when user's interest rates were updated
    mapping(address => uint256) private s_userLastUpdatedTimestamp;
    // Constant variable to track the precision factor
    uint256 private constant PRECISION_FACTOR = 1e18;
    // Role to allow minting and burning of tokens
    bytes32 public constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    // state variable to keep track of interest rate
    uint256 private s_interestRate = ( 5 * PRECISION_FACTOR ) / 1e8;

    // -------------- EVENTS -------------- 

    event InterestRateSet(uint256);

    // -------------- FUNCTIONS -------------- 

    constructor() ERC20("RebaseXToken", "RXT") Ownable(msg.sender) {}

    /**
    * @notice Grant the mint and burn role to an account
    * @param _account The account to grant the mint and burn role to
    */
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
    * @notice Set the interest rate in the contract
    * @notice _newInterestRate is the interest rate that is to be set
    * @dev The interest rate can only decrease
    */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if(_newInterestRate >= s_interestRate) {
            revert RebaseXToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;

        emit InterestRateSet(s_interestRate);
    }

    /**
    * @notice Mint the user tokens when they deposit into the vault
    * @param _to The user to mint the tokens to
    * @param _amount The amount of tokens to mint
    */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        // For users minting new tokens, mint any accured tokens since the last time the calculations was performed
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
    * @notice Get the interest rate for the user
    * @param _user The user to get the interest rate for
    * @return The interest rate for the user
    */
    function getUserInterestRate(address _user) external view returns(uint256) {
        return s_userInterestRate[_user];
    }

    /**
    * @notice Get the interest rate that is currently set for the protocol. 
    * @return The interest rate for the contract
    */
    function getInterestRate() external view returns(uint256) {
        return s_interestRate;
    }

    /**
    * Calculate the balance for the user including the interest that has accumulated since the deposit
    * (principle balance) + some interest that has accrued
    * @param _user The user to calculate the balance for
    * @return The balance of the user including the interest that has accumulated since the deposit
    */
    function balanceOf(address _user) public view override returns(uint256) {
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
    * @notice Calculate the interest that has accumulated since the last update
    * @param _user The user to calculate the interest accured since the deposit
    * @return linearInterest The interest that has accumulated since the last update
    */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) public view returns(uint256 linearInterest) {
        // interest = principle amount + priciple amount * interest * time = (principle amount * (1 + interest * time))
        uint256 timeElasped = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElasped);
        return linearInterest;
    }

    /**
    * @notice Mint the accrued interest to the user since the last time they interacted with the contract
    * @param _user The user to mint the accrued interest to
    */
    function _mintAccuredInterest(address _user) internal {
        uint256 previousPricipleBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncreased = currentBalance - previousPricipleBalance;
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncreased);
    }

    /**
    * @notice Burn the user tokens when they withdraw from the vault
    * @param _from The user from whom the tokens are to be burned
    * @param _amount The amount of tokens that has to be burned
    */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccuredInterest(_from);
        _burn(_from, _amount);
    }

    /**
    * @notice To view the principle balance of a given user. This amount may be inaccurate because it reflects tokens recently accrued by the user.
    * @param _user The user whose balance is to be viewed
    * @return The priciple balance of the given user
    */
    function principleBalanceOf(address _user) external view returns(uint256) {
        return super.balanceOf(_user);
    }

    /**
    * @notice Transfer tokens from one user to another user. Interest Rate will be updated to the current.
    * @param _recipient The user to transfer the tokens to.
    * @param _amount The amount of tokens to be transferred.
    * @return True if the transfer was successful
    */
    function transfer(address _recipient, uint256 _amount) public override returns(bool) {
        _mintAccuredInterest(msg.sender);
        _mintAccuredInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount  = balanceOf(msg.sender);
        }

        // Inter-wallet transfers for the same user will adjust the receiving wallet's interest rate to the current global interest rate.
        // This is implemented to mitigate the risk of users manipulating interest rates by initially investing small amounts to secure higher rates, 
        // and subsequently transferring larger amounts from other wallets to benefit from the locked-in rate.
        // This policy safeguards the protocol against potential long-term imbalances and ensures a fairer distribution of interest.
        if(balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_interestRate;
        }

        return super.transfer(_recipient, _amount);
    }

    /**
    * @notice Transfer tokens from one user to another user. Interest Rate will be updated to the current.
    * @param _recipient The user the tokens will be transferred from.
    * @param _recipient The user to transfer the tokens to.
    * @param _amount The amount of tokens to be transferred.
    * @return True if the transfer was successful
    */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns(bool) {
         _mintAccuredInterest(_sender);
        _mintAccuredInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount  = balanceOf(_sender);
        }

        // Inter-wallet transfers for the same user will adjust the receiving wallet's interest rate to the current global interest rate.
        // This is implemented to mitigate the risk of users manipulating interest rates by initially investing small amounts to secure higher rates, 
        // and subsequently transferring larger amounts from other wallets to benefit from the locked-in rate.
        // This policy safeguards the protocol against potential long-term imbalances and ensures a fairer distribution of interest.
        if(balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_interestRate;
        }

        return super.transferFrom(_sender, _recipient, _amount);
    }
}