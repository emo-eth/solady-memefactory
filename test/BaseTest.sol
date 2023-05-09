// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

contract BaseTest is Test {
    address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    function setUp() public virtual {
        vm.createSelectFork("mainnet", 17220629);
    }

    function getWethPairAddress(address coin) internal pure returns (address addy) {
        (address addy0, address addy1) = sortNames(address(coin), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        addy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            uint8(0xff),
                            0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f,
                            keccak256(abi.encodePacked(addy0, addy1)),
                            bytes32(0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f)
                        )
                    )
                )
            )
        );
    }

    function sortNames(address test0, address test1) internal pure returns (address, address) {
        if (test0 < test1) {
            return (test0, test1);
        } else {
            return (test1, test0);
        }
    }
}
