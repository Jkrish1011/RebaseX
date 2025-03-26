// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import { IRebaseXToken } from "./interfaces/IRebaseXToken.sol";

contract Vault {
    // -------------- ERRORS -------------- 
    error Vault__RedeemFailed();

    // -------------- STATE VARIABLES -------------- 
    IRebaseXToken private immutable i_rebaseXToken;
    
    // -------------- EVENTS -------------- 

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    // -------------- FUNCTIONS -------------- 

    constructor(IRebaseXToken _rebaseXToken) {
        i_rebaseXToken = _rebaseXToken;
    }
    
    /**
    * @notice Fallback function to send rewards to the vault
    */
    receive() external payable {

    }

    /**
    * @notice Allows users to deposit ETH into vault and mint rebase tokens in return
    */
    function deposit() external payable {
        i_rebaseXToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
    * @notice Allows users to redeem their rebase tokens for ETH
    * @param _amount The amount of token that the user wishes to redeem
    */
    function redeem(uint256 _amount) external {
        i_rebaseXToken.burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
    * @notice Getter function to get the address of the rebase token
    * @return The address of the rebase token
    */
    function getRebaseTokenAddress() external view returns(address) {
        return address(i_rebaseXToken);
    }
}