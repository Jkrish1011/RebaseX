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
        vm.assume(amount > 1e5);
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        // 1. Deposit
        vm.deal(user, amount);
        // 2. Check our rebase token balance
        // 3. warp the time and check the balance again
        // 4. warp the time gain by the same amount and check the balance again
    }
}
