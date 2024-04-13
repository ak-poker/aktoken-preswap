// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockAK is ERC20 {

    constructor() ERC20("Mock AK", "mAK") {
        _mint(msg.sender, 50000000 * (10 ** uint256(decimals())));
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}