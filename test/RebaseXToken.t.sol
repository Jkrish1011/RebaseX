// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { RebaseXToken } from "../src/RebaseXToken.sol";
import { Vault } from "../src/Vault.sol";
import { IRebaseXToken } from "../src/interfaces/IRebaseXToken.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract RebaseXTokenTest is Test {
    RebaseXToken private rebaseXToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseXToken = new RebaseXToken();
        vault = new Vault(IRebaseXToken(address(rebaseXToken)));
        rebaseXToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public  {
        (bool success, ) = payable(address(vault)).call{value: rewardAmount}("");
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        // 1. Deposit
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        // 2. Check our rebase token balance
        uint256 startBalance = rebaseXToken.balanceOf(user);
        console.log("startBalance", startBalance);
        assertEq(startBalance, amount);
        // 3. warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseXToken.balanceOf(user);
        assertGt(middleBalance, startBalance);
        // 4. warp the time gain by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseXToken.balanceOf(user);
        assertGt(endBalance, middleBalance);

        // Checking for amount of growth!
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        // 1. Depost funds
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseXToken.balanceOf(user), amount);

        // 2. Redeem
        vault.redeem(type(uint256).max);
        assertEq(rebaseXToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);

        // 1. Deposit
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // 2. warp the time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseXToken.balanceOf(user);
        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        // 2.(b) Add the rewards to the vault
        addRewardsToVault(balanceAfterSomeTime - depositAmount);
        console.log(balanceAfterSomeTime);
        
        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(user).balance;
        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, 0);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);
        // 1. deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseXToken.balanceOf(user);
        uint256 user2Balance = rebaseXToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        // Owner reduces the interest rate
        vm.prank(owner);
        rebaseXToken.setInterestRate(4e10);

        vm.prank(user);
        rebaseXToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseXToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseXToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        // Check if the user interest rate has been inherited (5e10 not 4e10)
        assertEq(rebaseXToken.getUserInterestRate(user), 5e10);
        // Check if the new user interest rate has not been inherited (4e10(new global interest rate) not 5e10)
        assertEq(rebaseXToken.getUserInterestRate(user2), 4e10);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);

        rebaseXToken.setInterestRate(newInterestRate);
    }

    function testCannotCallMintAndBurn() public {
        vm.prank(user);
        vm.expectRevert();
        rebaseXToken.mint(user, 100, rebaseXToken.getInterestRate());

        vm.expectRevert();
        rebaseXToken.burn(user, 100);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);

        vault.deposit{value: amount}();
        assertEq(rebaseXToken.principleBalanceOf(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseXToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseXToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseXToken.getInterestRate();
        newInterestRate =  bound(newInterestRate, initialInterestRate, type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(RebaseXToken.RebaseXToken__InterestRateCanOnlyDecrease.selector);
        rebaseXToken.setInterestRate(newInterestRate);
        assertEq(rebaseXToken.getInterestRate(), initialInterestRate);
    }

    function testAssignBurnAndMintRole(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(owner);
        rebaseXToken.grantMintAndBurnRole(user);
        

        vm.prank(user);
        rebaseXToken.mint(user, 100, rebaseXToken.getInterestRate());
        rebaseXToken.burn(user, 100);
    }
}
