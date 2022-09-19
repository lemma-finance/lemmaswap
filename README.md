
# LemmaSwap

LemmaSwap is to swap tokens for Erc20-Erc20, Eth-Erc20 and Erc20-Eth.
We are using the basis-trading-stablecoin underlying protocol to swap tokens. 

## Instructions 

1. Installation

```
forge install
```
 
or

```
forge install foundry-rs/forge-std
forge install Uniswap/v3-periphery
forge install Openzeppelin/openzeppelin-contracts
```

2. Use 

3.1 Build 

```
forge build
```

3.2 Test 

```
forge test
```

Adjust verbosity with 

```
forge test --fork-url https://kovan.optimism.io --fork-block-number 6664172 -vv
```

3.3

Test deployment scripts

```
forge script script/LemmaSwapDeployTestnet.sol --rpc-url $OPTIMISM_KOVAN_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
````