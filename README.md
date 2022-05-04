
# LemmaSwap

## Status 

I am now testing using the Optimism Kovan Testnet setup 

Currently I am focusing on this test 

```
forge test --fork-url https://kovan.optimism.io -m testSwap1
```

According to the trace I get, I can mint with WETH and WBTC successfully, so it means I can put collateral in the Perp Protocol 



## Instructions 

1. Installation

1.1 Install Foundry with 

```
curl -L https://foundry.paradigm.xyz | bash
source /home/nicolabernini/.bashrc
foundryup
```





1.2 Install Deps 

1.2.1 Install forge-std

```
forge install foundry-rs/forge-std
```

It is Forge Standard Library and contains useful stuff like `console.log()` command 



1.2.2 Install UniswapV3 Periphery 

```
forge install Uniswap/v3-periphery
```



1.2.3 Install OpenZeppelin Contracts 

```
forge install Openzeppelin/openzeppelin-contracts
```

Change the branch to `solc-0.7` for the compatibility with the Solidity Version used in the rest of the contracts running 

```
cd lib/openzeppelin-contracts/
git checkout solc-0.7
cd ../..
```





1.2.4 Install Solmate 

```
forge install Rari-Capital/solmate
```



2. Initialize Foundry Project with 

```
forge init
```

If the dir is not empty, use 

```
forge init --force
```





3. Use 

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
forge test -vvv
```

The more the `v` and the higher the verbosity 

To see the logs you need at least `-vvv` level












