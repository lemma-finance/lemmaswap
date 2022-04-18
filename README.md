
# LemmaSwap

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












