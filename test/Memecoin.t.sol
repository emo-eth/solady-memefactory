// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BaseTest} from "./BaseTest.sol";
import {Memecoin} from "../src/Memecoin.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract MemecoinTest is BaseTest {
    function testDeploy() public {
        uint256 startGas = gasleft();
        Memecoin memecoin =
        new Memecoin{value: 1 ether}({name_:'test', sym:"TEST", fullTotalSupply:69e18, _deployer:address(this), _teamBps: 1000, liquidityLockPeriodInSeconds:69});
        emit log_named_uint("gas used", startGas - gasleft());
        assertEq(memecoin.balanceOf(address(memecoin)), 69e18 - 69e17);
        assertEq(memecoin.allowance(address(memecoin), UNISWAP_ROUTER), 69e18 - 69e17);

        startGas = gasleft();
        address(memecoin).call(""); //._createPool();
        emit log_named_uint("gas used", startGas - gasleft());
        assertEq(memecoin.balanceOf(address(memecoin)), 0);
        assertEq(memecoin.allowance(address(memecoin), UNISWAP_ROUTER), 0);
        assertEq(address(memecoin).balance, 0);
        assertEq(memecoin.balanceOf(address(this)), 69e17);
        assertEq(IERC20(memecoin.UNISWAP_PAIR()).balanceOf(address(memecoin)), 7880355321938217288);
        assertEq(memecoin.owner(), address(this));
        assertEq(memecoin.totalSupply(), 69e18);
    }

    function testDeploy_TeamBpsTooLarge() public {
        vm.expectRevert(Memecoin.InvalidInitializationParams.selector);

        new Memecoin{value: 1 ether}({name_:'test', sym:"TEST", fullTotalSupply:69e18, _deployer:address(this), _teamBps: 10001, liquidityLockPeriodInSeconds:69});
    }

    function testDeploy_MsgValue0WholeTeamBps() public {
        // should pass
        Memecoin memecoin =
        new Memecoin{value: 0}({name_:'test', sym:"TEST", fullTotalSupply:69e18, _deployer:address(this), _teamBps: 10000, liquidityLockPeriodInSeconds:69});
        assertEq(memecoin.balanceOf(address(this)), 69e18);
    }

    function testDeploy_MsgValue0() public {
        vm.expectRevert(Memecoin.InvalidInitializationParams.selector);
        new Memecoin{value: 0}({name_:'test', sym:"TEST", fullTotalSupply:69e18, _deployer:address(this), _teamBps: 1000, liquidityLockPeriodInSeconds:69});
    }

    function testDeploy_0LengthName() public {
        vm.expectRevert(Memecoin.InvalidInitializationParams.selector);
        new Memecoin{value: 1 ether}({name_:'', sym:"TEST", fullTotalSupply:69e18, _deployer:address(this), _teamBps: 1000, liquidityLockPeriodInSeconds:69});
    }

    function testDeploy_0LengthSymbol() public {
        vm.expectRevert(Memecoin.InvalidInitializationParams.selector);
        new Memecoin{value: 1 ether}({name_:'test', sym:"", fullTotalSupply:69e18, _deployer:address(this), _teamBps: 1000, liquidityLockPeriodInSeconds:69});
    }

    function testDeploy_liquidityUnlockedUntilOverflow() public {
        vm.warp(10);
        Memecoin memecoin =
        new Memecoin{value: 1 ether}({name_:'test', sym:"TEST", fullTotalSupply:69e18, _deployer:address(this), _teamBps: 1000, liquidityLockPeriodInSeconds:type(uint256).max});
        assertEq(memecoin.LIQUIDITY_LOCKED_UNTIL(), type(uint256).max);
    }

    function testNameAndSymbol() public {
        Memecoin memecoin =
        new Memecoin{value: 1 ether}({name_:'test', sym:"TEST", fullTotalSupply:69e18, _deployer:address(this), _teamBps: 1000, liquidityLockPeriodInSeconds:69});
        assertEq(memecoin.name(), "test");
        assertEq(memecoin.symbol(), "TEST");
    }

    function testWithdrawLP() public {
        Memecoin memecoin =
        new Memecoin{value: 1 ether}({name_:'test', sym:"TEST", fullTotalSupply:69e18, _deployer:address(this), _teamBps: 1000, liquidityLockPeriodInSeconds:69});
        address(memecoin).call("");
        vm.expectRevert(Memecoin.LiquidityLocked.selector);
        memecoin.withdrawLP();

        vm.warp(memecoin.LIQUIDITY_LOCKED_UNTIL());
        memecoin.withdrawLP();
        assertEq(IERC20(memecoin.UNISWAP_PAIR()).balanceOf(address(this)), 7880355321938217288);
    }

    function testWithdrawLP0Seconds() public {
        Memecoin memecoin =
        new Memecoin{value: 1 ether}({name_:'test', sym:"TEST", fullTotalSupply:69e18, _deployer:address(this), _teamBps: 1000, liquidityLockPeriodInSeconds:0});
        address(memecoin).call("");
        memecoin.withdrawLP();
        assertEq(IERC20(memecoin.UNISWAP_PAIR()).balanceOf(address(this)), 7880355321938217288);
    }

    function testUniswapPair() public {
        Memecoin memecoin =
        new Memecoin{value: 1 ether}({name_:'test', sym:"TEST", fullTotalSupply:69e18, _deployer:address(this), _teamBps: 1000, liquidityLockPeriodInSeconds:69});
        assertEq(memecoin.UNISWAP_PAIR(), 0x35318373409608AFC0f2cdab5189B3cB28615008);

        assertEq(memecoin.UNISWAP_PAIR(), getWethPairAddress(address(memecoin)), "addy");
    }
}
