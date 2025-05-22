// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

interface IRebaseXToken {
    function mint(address _to, uint256 _amount, uint256 userInterestRate) external;
    function burn(address _to, uint256 _amount) external;
    function balanceOf(address _user) external returns(uint256);
    function getUserInterestRate(address _user) external view returns(uint256);
}