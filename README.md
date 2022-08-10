# Blackbox smart contracts

Blackbox smart contracts are developed on Hardhat framework, deployed on Polygon network and aims to provide decentralized, anonymous, and secured financial competition throughtout community. 
The smart contracts are non-upgradable and immutable in nature. 

## Using Blackbox interfaces
The Blackbox interfaces are available for import into solidity smart contracts via the npm artifact `@blackboxfinancetech/smart-contracts-blackbox`

Example contract using Blackbox interfaces

```
import "@blackboxfinancetech/smart-contracts-blackbox/contracts/interface/IBlackBox.sol"

contract weUseBlackBox  {
    IBlackBox immutable blackBox; 
    constructor(address _blackBoxAddress) {
      blackBox = IBlackBox(_blackBoxAddress);
    }
    
    function purchaseMoreBlackBox(uint _amount, _uint roundIndex, uint _side) public {
      blackBox.buyBlackBox(_amount, roundIndex, _side);
    }
}
```
## Address and verified source code 
Polygon mainnet
- BlackBox: https://polygonscan.com/address/0x1323522e0ac3bc5aaf01cd535730a31751e8a3ac
- BlackBoxInfo: https://polygonscan.com/address/0xc01aa0a448bc7abb8333b55d9632d2c966f32aeb
- FeeSharingSystem: https://polygonscan.com/address/0xa8e8bd018e0de2db5e8c034fb33256691ab0d95f
- PlatformToken: https://polygonscan.com/token/0xa6897eA12155A94fBd8fD4ecC18205A15A9c1AA7





