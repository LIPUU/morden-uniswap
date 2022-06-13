// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "./interfaces/INuniswapV2Factory.sol";
import "./interfaces/INuniswapV2Pair.sol";

library NuniswapV2Library{
    error InsufficientAmount();
    error InsufficientLiquidity();
    error InvalidPath();

    function sortTokens(address tokenA,address tokenB)
        internal
        pure
        returns(address token0,address token1)
    {
        return tokenA<tokenB?(tokenA,tokenB):(tokenB,tokenA);
    }

    // pair合约的creationCode用
    function pairFor(
        address factoryAddress,
        address tokenA,
        address tokenB
    ) internal pure returns(address pairAddress){
        (address token0,address token1)=sortTokens(tokenA,tokenB);
        pairAddress=address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factoryAddress,
                            keccak256(abi.encodePacked(token0,token1)),
                            hex"03f9437dee8a8ddf8af9c1b53ac64ecba926e956cb8a277e5e0899097016a733"
                        )
                    )
                )
            )
        );
    }

    function getReserves(
        address factoryAddress,
        address tokenA,
        address tokenB
    )public returns(uint256 reserveA,uint256 reserveB){
        (address token0,address token1)=sortTokens(tokenA,tokenB);
        
        (uint256 reserve0,uint256 reserve1,)=INuniswapV2Pair(
                pairFor(factoryAddress,token0,token1)
        ).getReserves();

        (reserveA,reserveB)=tokenA==token0
            ?(reserve0,reserve1)
            :(reserve1,reserve0);
    }


    function quote(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns(uint256 amountOut){
        if (amountIn == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        return (amountIn * reserveOut) / reserveIn;
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns(uint256){
        if (amountIn==0) 
            revert InsufficientAmount();
        if (reserveIn==0 || reserveOut==0)
            revert InsufficientLiquidity();
        
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator; // 向下取整，偏向流动性提供者
    }

    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path
    )public returns(uint256[] memory){
        if (path.length<2)
            revert InvalidPath();
        uint256[] memory amounts=new uint256[](path.length);
        amounts[0]=amountIn;

        for(uint256 i;i<path.length-1;++i){
            (uint256 reserve0,uint256 reserve1)=getReserves(
                    factory,
                    path[i],
                    path[i+1]
                );
            amounts[i+1]=getAmountOut(amounts[i],reserve0,reserve1);
            
        }
        return amounts;
    }
}
