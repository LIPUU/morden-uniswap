// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "./interfaces/INuniswapV2Factory.sol";
import "./interfaces/INuniswapV2Pair.sol";
import "./NuniswapV2Library.sol";

contract NuniswapV2Router{
    error SafeTransferFailed();
    error InsufficientAAmount();
    error InsufficientBAmount();
    error InsufficientOutputAmount();
    
    INuniswapV2Factory factory;
    constructor(address factoryAddress){
        factory=INuniswapV2Factory(factoryAddress);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    )
        public 
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        if(factory.pairs(tokenA,tokenB)==address(0)){
            factory.createPair(tokenA,tokenB);
        }

        (amountA,amountB)=_calculateLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        address pairAddress = NuniswapV2Library.pairFor(
            address(factory),
            tokenA,
            tokenB
        );

        _safeTransferFrom(tokenA, msg.sender, pairAddress, amountA);
        _safeTransferFrom(tokenB, msg.sender, pairAddress, amountB);
        liquidity = INuniswapV2Pair(pairAddress).mint(to);
    }
    
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin, // 防止退还的币量达不到用户预期的最小量
        uint256 amountBMin,
        address to // 一般情况下to设为调用该函数的msg.sender
    ) public returns (uint256 amountA, uint256 amountB) {
        address pair = NuniswapV2Library.pairFor( // 根据两种币的地址找到已经部署的pair地址
            address(factory),
            tokenA,
            tokenB
        );

        // 凡是能执行transferFrom，都是事先授权过的.ERC20在设计上只允许EOA调用approve
        // 查看transferFrom的文档，transferFrom的调用者应该是router合约，因为用户提前授权给了router
        // transferFrom需要提供第一个参数的原因是router可能被好多用户授权。因此需要知道这次转移的是哪个用户的token
        INuniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // 把LP-token打回给pair
        // 参数列表中msg.sender是调用removeLiquidity的用户地址
        // 但是如果在transferFrom中写下msg.sender，该msg.sender其实是router地址，因为是router调用的transferFrom
        // 这是合理的，因为router有权利调用transferFrom以便从用户的地址中划给pair不大于授权量的liquidity

        (amountA, amountB) = INuniswapV2Pair(pair).burn(to);
        if (amountA < amountAMin) revert InsufficientAAmount();
        if (amountA < amountBMin) revert InsufficientBAmount();

    }


    // 可以防止用户因为计算失误导致利益受损
    function _calculateLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        (uint256 reserveA, uint256 reserveB) = NuniswapV2Library.getReserves(
            address(factory),
            tokenA,
            tokenB
        );

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
            // 如果池子中没有任何流动性，就按照用户要求的的数量添加上流动性

        } else {
        // 如果池子中已经有流动性，那么就要考虑提供不均衡的流动性会导致得到的LP-token受惩罚。这不光导致手续费变少，
        // 更会导致在撤出流动性的时候硬性损失token

            // quote:开价，报价
            uint256 amountBOptimal = NuniswapV2Library.quote(
                // 这个值一般情况下等于approve的数量，毕竟用户想要添加多少流动性，就会通过approve允许router最大能划给pair多少量
                // 但不能大于approve的量
                amountADesired, 

                reserveA,
                reserveB
            );
            // 如果B的最优解(该最优解是按照用户给的A的量计算的)小于用户提供的量，那么说明用户提供的量能满足最优解。
            // 用户提供的量可以认为是token的最大量
            if (amountBOptimal <= amountBDesired) {
                // amountBMin是用户期望的添加的token的最小量，小于该量用户认为是不可接受的。
                if (amountBOptimal <= amountBMin)  
                // 注意此处有等号
                    revert InsufficientBAmount();
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {

                uint256 amountAOptimal = NuniswapV2Library.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);

                if (amountAOptimal <= amountAMin) 
                    revert InsufficientAAmount();
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
        
    }
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path, // 这个path最优路径应该是前端计算出来的
        address to
    ) public returns (uint256[] memory amounts) {

        amounts = NuniswapV2Library.getAmountsOut(
            address(factory),
            amountIn,
            path
        );
        // amounts中放了兑换路径上所有币的数量

        if (amounts[amounts.length - 1] < amountOutMin)
            revert InsufficientOutputAmount();
        // 先计算，检查计算结果是否满足用户要求，计算之后再进行实际兑换

        _safeTransferFrom(
            path[0], 
            msg.sender,
            NuniswapV2Library.pairFor(address(factory), path[0], path[1]),
            amounts[0]
        );
        // 此时，用户通过approve提前授权给router的amountIn的币(也就是amounts[0])被划给了路径上第一个pair合约
        // 是换币的初始资金。比如路径是OKB->DAI->ETH,那么OKB就是初始资金

        _swap(amounts, path, to);
        // 执行真正的换币操作，OKB换到DAI，再换到ETH
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) private {
        (bool success,bytes memory data)= token.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                to,
                value
            )
        );
        if(!success || (data.length!=0 && !abi.decode(data,(bool))))
            revert SafeTransferFailed();
        
    }

    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address to_
    ) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);

            (address token0, ) = NuniswapV2Library.sortTokens(input, output);

            uint256 amountOut = amounts[i + 1]; // 本次兑换换出的币的数量

            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));

            address to = i < path.length - 2 // 如果这个成立说明还没换到头
                ? NuniswapV2Library.pairFor(
                    address(factory),
                    output, // path[i+1]
                    path[i + 2]
                )
                : to_;
            INuniswapV2Pair(
                // 假设路径是token0 token1 token2,token3,i=0,则下面这行代码算出来的是token0和token1的pair
                // 而上面的to是token1和token2的pair
                NuniswapV2Library.pairFor(address(factory), input, output) 
            ).swap(amount0Out, amount1Out, to, ""); // 
        }     // 把上一个pair的输出币种打一定的量给下一个pair
    }
}
