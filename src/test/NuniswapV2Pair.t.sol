// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;
import "forge-std/Test.sol";
import "../NuniswapV2Factory.sol";
import "../NuniswapV2Pair.sol";
import "../mocks/ERC20Mintable.sol";
import "../libraries/UQ112x112.sol";

// helper contract
contract TestUser {
    function provideLiquidity(
        address pairAddress_,
        address token0Address_,
        address token1Address_,
        uint256 amount0_,
        uint256 amount1_
    ) public {
        // 在一笔交易内完成给pair打流动性及mint LP-token
        ERC20(token0Address_).transfer(pairAddress_, amount0_);
        ERC20(token1Address_).transfer(pairAddress_, amount1_);
        INuniswapV2Pair(pairAddress_).mint(address(this));
    }

    function removeLiquidity(address pairAddress_) public{
        uint256 liquidity=ERC20(pairAddress_).balanceOf(address(this));
        ERC20(pairAddress_).transfer(pairAddress_, liquidity);
        // 把LP-token打回给pair合约

        // burn前，pair合约会检查自己收到的LP-token的数量
        INuniswapV2Pair(pairAddress_).burn(address(this));
    }
}

// 合约闪电贷用户
contract Flashloaner {
    error InsufficientFlashLoanAmount();
    uint256 expectedLoanAmount;
    
    function flashloan(
        address pairAddress,
        uint256 amount0Out,
        uint256 amount1Out,
        address tokenAddress
    ) public {
        if (amount0Out > 0) {
            expectedLoanAmount = amount0Out;
        }
        if (amount1Out > 0) {
            expectedLoanAmount = amount1Out;
        }

        NuniswapV2Pair(pairAddress).swap(
            amount0Out,
            amount1Out,
            address(this),
            abi.encode(tokenAddress)
        );
    }

    // pair.swap把相应数量的token打给本合约之后回调该函数
    // 该函数在拿到币之后疯狂操作最后把借来的币+利息打回给pair
    function NuniswapV2Call(
        address sender,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata data
    ) public {
        address tokenAddress = abi.decode(data,(address));
        uint256 balance=ERC20(tokenAddress).balanceOf(address(this));
        if ( balance < expectedLoanAmount )
            revert InsufficientFlashLoanAmount();

        // msg.sender是pair合约    
        ERC20(tokenAddress).transfer(msg.sender,balance);
        // 把balance打回给pair合约。balance的组成部分应该是手续费+借来的币的数量
    }
}

contract NuniswapV2PairTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    NuniswapV2Pair pair;
    TestUser testUser;

    function setUp() public {
        testUser =new TestUser();
        token0 = new ERC20Mintable("Token A", "A");
        token1 = new ERC20Mintable("Token B", "B");
        // 部署了一个工厂合约
        NnuiswapV2Factory factory=new NnuiswapV2Factory();
        address pairAddress = factory.createPair(
            address(token0),
            address(token1)
        );

        pair=NuniswapV2Pair(pairAddress);

        token0.mint(10 ether,address(this));
        token1.mint(10 ether,address(this));

        token0.mint(10 ether,address(testUser));
        token1.mint(10 ether,address(testUser));
        
    }

    function encodeError(string memory error) 
        internal 
        pure
        returns(bytes memory encoded)
    {
        encoded=abi.encodeWithSignature(error);
    }

    function encodeError(string memory error,uint256 a)
        internal
        pure
        returns ( bytes memory encoded)
    {
        encoded=abi.encodeWithSignature(error,a);
    }

    function assertReserves(uint112 expectedReserve0,uint112 expectedReserve1)
        internal
    {
        (uint112 reserve0,uint112 reserve1,)=pair.getReserves();
        assertEq(expectedReserve0,reserve0,"unexpected reserve0");
        assertEq(expectedReserve1,reserve1,"unexpected reserve1");
    }

    
    
}
