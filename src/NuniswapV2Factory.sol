// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "./NuniswapV2Pair.sol";
import "./interfaces/INuniswapV2Pair.sol";

contract NnuiswapV2Factory{
    error IdenticalAddresses();
    error ZeroAddress();
    error PairExists();

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    mapping(address=>mapping(address=>address)) public pairs;
    address[] public allPairs;

    function createPair(address tokenA,address tokenB) 
        public 
        returns(address pair)
    {
        if (tokenA==tokenB)
            revert IdenticalAddresses();

        (address token0,address token1)=tokenA<tokenB
            ?(tokenA,tokenB)
            :(tokenB,tokenA);
        
        if (token0==address(0))
            revert ZeroAddress();

        if(pairs[token0][token1]!=address(0))
            revert PairExists();

        bytes memory bytecode = type(NuniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0,token1));

        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        NuniswapV2Pair(pair).initialize(token0,token1);
        
        pairs[token0][token1]=pair;
        pairs[token1][token0]=pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}
