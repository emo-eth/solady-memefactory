// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BaseTest} from "./BaseTest.sol";
import {MemeFactory} from "../src/MemeFactory.sol";
import {Memecoin} from "../src/Memecoin.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {CommitReveal} from "../src/CommitReveal.sol";

contract MemeFactoryTest is BaseTest {
    MemeFactory test;

    function setUp() public override {
        super.setUp();
        test = new MemeFactory();
    }

    function testDeployFactory() public {
        bytes32 validationSalt = bytes32("validation");
        string memory name = "test";
        bytes32 commitmentHash = test.calculateCommitmentHash(name, validationSalt);
        uint256 ts = block.timestamp;
        vm.warp(block.timestamp - test.COMMITMENT_PERIOD());
        test.commit(commitmentHash);
        vm.warp(ts);
        Memecoin meme = Memecoin(
            test.deployMeme{value: 1 ether}({
                name: name,
                sym: "TEST",
                totalSupply: 69,
                teamBps: 1000,
                liquidityLockPeriodInSeconds: 420,
                salt: validationSalt
            })
        );
        assertEq(meme.name(), name);
        assertEq(meme.symbol(), "TEST");
        assertEq(meme.totalSupply(), 69 * 1e18);
        assertEq(meme.LIQUIDITY_LOCKED_UNTIL(), block.timestamp + 420);
        assertEq(IERC20(meme.UNISWAP_PAIR()).balanceOf(address(meme)), 7880355321938217288);

        // try and fail to deploy the same meme again
        try test.deployMeme{value: 1 ether}({
            name: name,
            sym: "TEST",
            totalSupply: 69,
            teamBps: 1000,
            liquidityLockPeriodInSeconds: 420,
            salt: validationSalt
        }) {
            fail("should have reverted");
        } catch {
            // pass
        }
    }

    function testDeploy_InvalidCommitment() public {
        bytes32 validationSalt = bytes32("validation");
        string memory name = "test";
        bytes32 commitmentHash = test.calculateCommitmentHash(name, validationSalt);
        test.commit(commitmentHash);
        vm.expectRevert(CommitReveal.InvalidCommitment.selector);
        test.deployMeme{value: 1 ether}({
            name: name,
            sym: "TEST",
            totalSupply: 69,
            teamBps: 1000,
            liquidityLockPeriodInSeconds: 420,
            salt: bytes32("invalid")
        });
    }

    function testDeploy_NoPool() public {
        bytes32 validationSalt = bytes32("validation");
        string memory name = "test";
        bytes32 commitmentHash = test.calculateCommitmentHash(name, validationSalt);
        test.commit(commitmentHash);
        vm.warp(block.timestamp + test.COMMITMENT_PERIOD());
        Memecoin meme = Memecoin(
            test.deployMeme{value: 1 ether}({
                name: name,
                sym: "TEST",
                totalSupply: 69,
                teamBps: 10000,
                liquidityLockPeriodInSeconds: 420,
                salt: validationSalt
            })
        );
        assertEq(meme.UNISWAP_PAIR().code.length, 0);
    }

    function testDeploy_AmountZero() public {
        bytes32 validationSalt = bytes32("validation");
        string memory name = "test";
        bytes32 commitmentHash = test.calculateCommitmentHash(name, validationSalt);
        test.commit(commitmentHash);
        vm.warp(block.timestamp + test.COMMITMENT_PERIOD());
        test.deployMeme{value: 0}({
            name: name,
            sym: "TEST",
            totalSupply: 0,
            teamBps: 10000,
            liquidityLockPeriodInSeconds: 0,
            salt: validationSalt
        });
    }
}
