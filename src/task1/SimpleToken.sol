// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleToken {
    string public name = "Test Token";
    uint256 public supply = 1000;

    function getSupply() public view returns (uint256) {
        return supply;
    }
}
