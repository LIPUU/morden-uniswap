// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../NuniswapV2Factory.sol";
import "../NuniswapV2Pair.sol";
import "../NuniswapV2Router.sol";
import "../mocks/ERC20Mintable.sol";
import "forge-std/console.sol";

contract NuniswapV2RouterTest is Test {
    NuniswapV2Factory factory;
    NuniswapV2Router router;

    ERC20Mintable tokenA;
    ERC20Mintable tokenB;
    ERC20Mintable tokenC;

    function setUp() public{
        factory=new NuniswapV2Factory();
        router=new NuniswapV2Router(address(factory));
        
        tokenA = new ERC20Mintable("Token A", "TKNA");
        tokenB = new ERC20Mintable("Token B", "TKNB");
        tokenC = new ERC20Mintable("Token C", "TKNC");

        tokenA.mint(20 ether, address(this));
        tokenB.mint(20 ether, address(this));
        tokenC.mint(20 ether, address(this));
    }

    // 给expectRevert用
    function encodeError(string memory error)
        internal
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encodeWithSignature(error);
    }

    function testAddLiquidityCreatesPair() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        address pairAddress = factory.pairs(address(tokenA), address(tokenB));
        
        // create2计算的地址是可预测且固定的
        assertEq(pairAddress, 0xBdC67a297C360c07A70be7BBd875109bF08A38C1);
        console.log("FUCK:",pairAddress);
    }

    function testAddLiquidityNoPair() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                address(tokenA),
                address(tokenB),
                1 ether,
                1 ether,
                1 ether,
                1 ether,
                address(this)
            );

        assertEq(amountA, 1 ether);
        assertEq(amountB, 1 ether);
        assertEq(liquidity, 1 ether - 1000);

        address pairAddress = factory.pairs(address(tokenA), address(tokenB));

        assertEq(tokenA.balanceOf(pairAddress), 1 ether);
        assertEq(tokenB.balanceOf(pairAddress), 1 ether);

        // 得到一个可在上面调用函数的ZuniswapV2Pair实例
        NuniswapV2Pair pair = NuniswapV2Pair(pairAddress); 

        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));
        assertEq(pair.totalSupply(), 1 ether);
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);

        assertEq(tokenA.balanceOf(address(this)), 19 ether);
        assertEq(tokenB.balanceOf(address(this)), 19 ether);
    }

    function testAddLiquidityAmountBOptimalIsOk() public {
        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );

        NuniswapV2Pair pair = NuniswapV2Pair(pairAddress);

        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));

        tokenA.transfer(pairAddress, 1 ether); // 初始流动性的添加直接和pair合约交互，没有走router
        tokenB.transfer(pairAddress, 2 ether);
        pair.mint(address(this)); // 添加初始流动性并获得LP-token

        // 继续添加流动性。这次添加很显然需要考虑不平衡情况
        // 由于在已有的流动性上添加新流动性需要计算的情况比较复杂，因此通过router提供的addLiquidity方法进行操作
        // router.addLiquidity需要在ERC20上通过transferFrom把钱从LP账户中划到pair上，
        // 因此用户要先调用approve批准router的allowance，这样router就有权利把用户的token划给任何账户：当然这里肯定是划给pair对

        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                address(tokenA),
                address(tokenB),
                1 ether,
                2 ether,
                1 ether,
                1.9 ether,
                address(this)
            );

        assertEq(amountA, 1 ether);
        assertEq(amountB, 2 ether);
        assertEq(liquidity, 1414213562373095048);
    }

    function testAddLiquidityAmountBOptimalIsTooLow() public {
        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );

        NuniswapV2Pair pair = NuniswapV2Pair(pairAddress);
        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));
        
        tokenA.transfer(pairAddress, 5 ether);
        tokenB.transfer(pairAddress, 10 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);

        vm.expectRevert(encodeError("InsufficientBAmount()"));
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            2 ether,
            1 ether,
            2 ether,
            address(this)
        );
    }

    function testRemoveLiquidity() public {
        tokenA.approve(address(router),1 ether);
        tokenB.approve(address(router),1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        address pairAddress = factory.pairs(address(tokenA), address(tokenB));
        NuniswapV2Pair pair = NuniswapV2Pair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));
        assertEq(liquidity,1 ether-1000);

        pair.approve(address(router),liquidity);
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            1 ether - 1000,
            1 ether - 1000,
            address(this)
        );
        (uint256 reserve0,uint256 reserve1,)=pair.getReserves();
        assertEq(reserve0,1000);
        assertEq(reserve1,1000);
        assertEq(pair.balanceOf(address(this)),0);
        assertEq(pair.balanceOf(address(0)),1000);
        assertEq(pair.totalSupply(),1000);
        assertEq(tokenA.balanceOf(address(this)),20 ether -1000);
        assertEq(tokenB.balanceOf(address(this)),20 ether -1000);
        
    }

    function testRemoveLiquidityPartially() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        address pairAddress = factory.pairs(address(tokenA), address(tokenB));
        NuniswapV2Pair pair = NuniswapV2Pair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        liquidity = (liquidity * 3) / 10;
        pair.approve(address(router), liquidity);

        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0.3 ether - 300,
            0.3 ether - 300,
            address(this)
        );

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 0.7 ether + 300);
        assertEq(reserve1, 0.7 ether + 300);
        assertEq(pair.balanceOf(address(this)), 0.7 ether - 700);
        assertEq(pair.totalSupply(), 0.7 ether + 300);
        assertEq(tokenA.balanceOf(address(this)), 20 ether - 0.7 ether - 300);
        assertEq(tokenB.balanceOf(address(this)), 20 ether - 0.7 ether - 300);
    }

    function testSwapExactTokensForTokens() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);
        tokenC.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        // 允许router从本地址的余额中划走0.3ether数量个tokenA
        // 为了允许后面的交换代币C
        tokenA.approve(address(router), 0.3 ether); 

        router.swapExactTokensForTokens(
            0.3 ether, // A
            0.1 ether, // 最少能接收换出来的C的数量
            path, // 交换路径
            address(this)
        );

        assertEq(
            tokenA.balanceOf(address(this)), // 交换路径是A->B->C, router合约为了完成交换，把0.3个A给划走了
            20 ether - 1 ether - 0.3 ether
        );
        assertEq(tokenB.balanceOf(address(this)), 20 ether - 2 ether); // 用户并未得到更多的B，因为B是过客，被拿去换C了
        assertApproxEqRel(
            tokenC.balanceOf(address(this)),
            20 ether - 1 ether + 0.18 ether ,// 这个是手算出来的吗。。？
            0.001 ether
        );
    }
}