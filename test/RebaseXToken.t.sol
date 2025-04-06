// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import { Test, console } from "forge-std/Test.sol";
import { RebaseXToken } from "../src/RebaseXToken.sol";
import { Vault } from "../src/Vault.sol";
import { IRebaseXToken } from "../src/interfaces/IRebaseXToken.sol";

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
        (bool success, ) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
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
}
