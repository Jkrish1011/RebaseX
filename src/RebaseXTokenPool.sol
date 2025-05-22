//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TokenPool } from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import { Pool } from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import { IERC20 } from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import { IRebaseXToken } from "./interfaces/IRebaseXToken.sol";

contract RebaseXTokenPool is TokenPool {
    constructor(IERC20 _token, address[] memory _allowedList, address _rnmProxy, address _router) TokenPool(_token, _allowedList, _rnmProxy, _router) {}

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) external returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut) {
        _validateLockOrBurnIn(lockOrBurnIn);
        address originalSender = abi.decode(lockOrBurnIn.originalSender, (address));
        uint256 userInterestRate = IRebaseXToken(address(i_token)).getUserInterestRate(originalSender);
        // The token is sent to the CCIP token pool, then it is sent to the receiver. So we need to approve CCIP token pool to spend the token later on
        IRebaseXToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) external returns (Pool.ReleaseOrMintOutV1 memory) {
        _validateReleaseOrMintIn(releaseOrMintIn);
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        IRebaseXToken(address(i_token)).mint(releaseOrMintIn.receiver, releaseOrMintIn.amount, userInterestRate);

        return Pool.ReleaseOrMintOutV1({
            destinationAmount: releaseOrMintIn.amount
        });
    }
}