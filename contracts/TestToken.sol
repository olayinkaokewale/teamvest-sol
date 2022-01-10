//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {

    constructor(uint256 __totalSupply) ERC20("K90", "K90") {
        _mint(_msgSender(), __totalSupply * 10 ** decimals());
    }

}