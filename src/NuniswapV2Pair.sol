// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;
import "solmate/tokens/ERC20.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";
import "./interfaces/INuniswapV2Callee.sol";

interface IERC20{
    function balanceOf(address) external returns (uint256);
    function transfer(address to, uint256 amount) external;
}

