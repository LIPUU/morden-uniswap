// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

library UQ112x112 {
    uint224 constant Q112 = 2**112; // 2进制，1后面112个0

    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // 等于将该uint112类型的数字后面添加112个0,拓展到uint224
    }

    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}

// uqdiv:
// 假设x是46336,y是40123，最后参与计算的时候都转成uint224
// x：UQ112x112.encode(reserve0_).uqdiv(reserve1_)
