// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FeeToken is ERC20, Ownable {
    uint256 private immutable _SUPPLY_CAP;

    constructor(address _premintReceiver, uint256 _cap) ERC20("USDC", "USDC") {
        // Transfer the sum of the premint to address
        _mint(_premintReceiver, _cap);
        _SUPPLY_CAP = _cap;
    }

    /**
     * @notice View supply cap
     */
    function SUPPLY_CAP() external view returns (uint256) {
        return _SUPPLY_CAP;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
