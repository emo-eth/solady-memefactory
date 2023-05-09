// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {CommitReveal} from "../src/CommitReveal.sol";

contract TestCommitReveal is CommitReveal {
    function validateCommitment(bytes32 salt, string calldata name) external view {
        _validateCommitment(salt, name);
    }

    function compareToMapping(address committer, bytes32 commitmentHash)
        external
        view
        returns (uint256 assemblyRetrieved, uint256 solidityRetrieved)
    {
        return (getCommitment(committer, commitmentHash), _commitments[committer][commitmentHash]);
    }
}

contract CommitRevealTest is Test {
    TestCommitReveal test;

    function setUp() public {
        test = new TestCommitReveal();
    }

    function test_commit() public {
        vm.warp(69);
        bytes32 commitmentHash = keccak256(abi.encodePacked("test"));
        test.commit(commitmentHash);
        assertEq(test.getCommitment(address(this), commitmentHash), block.timestamp);

        (uint256 assemblyRetrieved, uint256 solidityRetrieved) = test.compareToMapping(address(this), commitmentHash);
        assertEq(assemblyRetrieved, solidityRetrieved, "assemblyRetrieved != solidityRetrieved");
    }

    function testCommit(address caller, bytes32 commitmentHash, uint256 timestamp) public {
        vm.warp(timestamp);
        vm.prank(caller);
        test.commit(commitmentHash);
        assertEq(test.getCommitment(caller, commitmentHash), timestamp);

        (uint256 assemblyRetrieved, uint256 solidityRetrieved) = test.compareToMapping(caller, commitmentHash);
        assertEq(assemblyRetrieved, solidityRetrieved, "assemblyRetrieved != solidityRetrieved");
    }

    function test_validateCommitment() public {
        uint256 start = 69696969;
        vm.warp(start);
        bytes32 validationSalt = bytes32(uint256(1));
        string memory name = "test";
        bytes32 commitmentHash = test.calculateCommitmentHash(name, validationSalt);

        // no commitment
        vm.expectRevert(CommitReveal.InvalidCommitment.selector);
        test.validateCommitment(validationSalt, name);

        test.commit(commitmentHash);

        // committment too new

        vm.expectRevert(CommitReveal.InvalidCommitment.selector);
        test.validateCommitment(validationSalt, name);

        // commitment too old
        vm.warp(start + test.COMMITMENT_LIFESPAN() + 1);
        vm.expectRevert(CommitReveal.InvalidCommitment.selector);
        test.validateCommitment(validationSalt, name);

        // commitment just right
        vm.warp(start + test.COMMITMENT_DELAY());
        test.validateCommitment(validationSalt, name);
    }

    function test_validateCommitmentFuzz(
        uint256 start,
        address caller,
        string calldata name,
        bytes32 validationSalt,
        uint256 validDelay
    ) public {
        start = bound(start, 1 days + 1, type(uint256).max - 1 days - 1);
        vm.assume(bytes(name).length > 0);
        validDelay = bound(validDelay, test.COMMITMENT_DELAY(), test.COMMITMENT_LIFESPAN());
        emit log_named_uint("name length", bytes(name).length);
        vm.warp(start);
        bytes32 commitmentHash = test.calculateCommitmentHash(name, validationSalt);

        vm.startPrank(caller);
        // no commitment
        vm.expectRevert(CommitReveal.InvalidCommitment.selector);
        test.validateCommitment(validationSalt, name);

        // too new
        test.commit(commitmentHash);
        vm.expectRevert(CommitReveal.InvalidCommitment.selector);
        test.validateCommitment(validationSalt, name);

        // too old
        vm.warp(start + test.COMMITMENT_LIFESPAN() + 1);
        vm.expectRevert(CommitReveal.InvalidCommitment.selector);
        test.validateCommitment(validationSalt, name);

        // just right
        vm.warp(start + validDelay);
        test.validateCommitment(validationSalt, name);

        vm.stopPrank();
    }
}
