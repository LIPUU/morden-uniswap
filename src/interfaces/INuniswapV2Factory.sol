// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

// interface就是abi
interface INuniswapV2Factory {
    // interface就是abi。pairs是个public mapping
    function pairs(address, address) external pure returns (address);
    
    function createPair(address, address) external returns (address);
}
