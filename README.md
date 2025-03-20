# RebaseX - Cross-chain Rebase Token

A protocol that allows user to deposit into a vault and in return, receive RebaseX tokens that represent their underlying balance

### Features

1. Rebase Token -> balanceOf function is dynamic to show the changing balance with time
    - Balance increases linearly with time.
    - mint tokens to our users every time they perform an action (minting, burning, transferring, or bridging)

2. Interest Rate
    - Individually set an interest rate or each user based on some global interest rate of the protocol at the time the user deposits into the vault.
    - The global interest rate can only decrease to incentivise/reward early adopters. 

#### NOTE: If you do a interwallet transfer, your interest rate will be set to the current global interest rate. This is to avoid any manipulations.