// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


/*
* @title RebaseXToken
* @author Jayakrishnan Ashok
* @notice A Cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
* @notice The interest rate in the smart contract can only decrease.
* @notice Each user will have their own interest rate that is the global interest rate at the time they mint the token.
*/
contract RebaseXToken is ERC20 {
    // -------------- ERRORS -------------- 

    error RebaseXToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    // -------------- STATE VARIABLES -------------- 

    // state variable to keep track of interest rate
    uint256 private s_interestRate = 5e10;
    // State variable to keep track of user's interest rates
    mapping(address => uint256) private s_userInterestRate;
    // State variable to keep track of when user's interest rates were updated
    mapping(address => uint256) private s_userLastUpdatedTimestamp;
    // Constant variable to track the precision factor
    uint256 private constant PRECISION_FACTOR = 1e18;

    // -------------- EVENTS -------------- 

    event InterestRateSet(uint256);

    // -------------- FUNCTIONS -------------- 

    constructor() ERC20("RebaseXToken", "RXT") {}

    /*
    * @notice Set the interest rate in the contract
    * @notice _newInterestRate is the interest rate that is to be set
    * @dev The interest rate can only decrease
    */
    function setInterestRate(uint256 _newInterestRate) external {
        if(_newInterestRate < s_interestRate) {
            revert RebaseXToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;

        emit InterestRateSet(s_interestRate);
    }

    /*
    * @notice Mint the user tokens when they deposit into the vault
    * @param _to The user to mint the tokens to
    * @param _amount The amount of tokens to mint
    */
    function mint(address _to, uint256 _amount) external {
        // For users minting new tokens, mint any accured tokens since the last time the calculations was performed
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /*
    * @notice Get the interest rate for the user
    * @param _user The user to get the interest rate for
    * @return The interest rate for the user
    */
    function getUserInterestRate(address _user) external view returns(uint256) {
        return s_userInterestRate[_user];
    }

    /*
    * Calculate the balance for the user including the interest that has accumulated since the deposit
    * (principle balance) + some interest that has accrued
    * @param _user The user to calculate the balance for
    * @return The balance of the user including the interest that has accumulated since the deposit
    */
    function balanceOf(address _user) public view override returns(uint256) {
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /*
    * @notice Calculate the interest that has accumulated since the last update
    * @param _user The user to calculate the interest accured since the deposit
    * @return THe interest that has accumulated since the last update
    */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) public view returns(uint256 linearInterest) {
        // interest = principle amount + priciple amount * interest * time = (principle amount * (1 + interest * time))
        uint256 timeElasped = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElasped);
        return linearInterest;
    }

    /*
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

    /*
    * @notice Burn the user tokens when they withdraw from the vault
    * @param _from The user from whom the tokens are to be burned
    * @param _amount The amount of tokens that has to be burned
    */
    function burn(address _from, uint256 _amount) external {
        // Mitigation against `dust`
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccuredInterest(_from);
        _burn(_from, _amount);
    }
}