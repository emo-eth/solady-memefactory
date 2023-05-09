// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BaseTest} from "./BaseTest.sol";
import {IQuitMemeFactory} from "../src/interface/IQuitMemeFactory.sol";
import {MemeFactory} from "../src/MemeFactory.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract SnapshotsTest is BaseTest {
    IQuitMemeFactory og = IQuitMemeFactory(0x3E9491cb1337b9F5322af7F5A5e431383B282076);
    MemeFactory factory;
    IERC20 ogMemecoin;
    IERC20 soladyMemecoin;

    function setUp() public override {
        super.setUp();
        factory = new MemeFactory();
        ogMemecoin = IERC20(og.deployMeme{value: 1 ether}("x", "X", 69, 10, 420));

        bytes32 hash = factory.calculateCommitmentHash("x", bytes32("salt"));
        factory.commit(hash);
        vm.warp(block.timestamp + factory.COMMITMENT_PERIOD());
        soladyMemecoin = IERC20(factory.deployMeme{value: 1 ether}("x", "X", 69, 10, 420, "salt"));
    }

    function testDeploy_snapshot() public {
        bytes memory call = abi.encodeCall(og.deployMeme, ("test", "TEST", 69, 10, 420));
        uint256 startGas = gasleft();
        address(og).call{value: 1 ether}(call);
        emit log_named_uint("OG Deploy: gas used", startGas - gasleft());
        bytes32 validationhash = factory.calculateCommitmentHash("test", bytes32("salt"));
        bytes memory commitCall = abi.encodeCall(factory.commit, (validationhash));
        call = abi.encodeCall(factory.deployMeme, ("test", "TEST", 69, 1000, 420, bytes32("salt")));
        uint256 nextTimestamp = block.timestamp + factory.COMMITMENT_PERIOD();
        startGas = gasleft();
        address(factory).call(commitCall);
        uint256 checkpoint = startGas - gasleft();
        vm.warp(nextTimestamp);
        startGas = gasleft();
        address(factory).call{value: 1 ether}(call);
        emit log_named_uint("Deploy: gas used", startGas - gasleft() + checkpoint);
    }

    function testTransfer_snapshot() public {
        address target = makeAddr("target");
        uint256 startGas = gasleft();
        ogMemecoin.transfer(address(target), 100);
        emit log_named_uint("OG Transfer: gas used", startGas - gasleft());
        startGas = gasleft();
        soladyMemecoin.transfer(address(target), 100);
        emit log_named_uint("Transfer: gas used", startGas - gasleft());
    }

    function testApprove_snapshot() public {
        address target = makeAddr("target");
        uint256 startGas = gasleft();
        ogMemecoin.approve(address(target), 100);
        emit log_named_uint("OG Approve: gas used", startGas - gasleft());
        startGas = gasleft();
        soladyMemecoin.approve(address(target), 100);
        emit log_named_uint("Approve: gas used", startGas - gasleft());
    }

    function testTransferFrom_snapshot() public {
        address target = makeAddr("target");
        address caller = makeAddr("caller");
        ogMemecoin.approve(address(caller), 101);
        soladyMemecoin.approve(address(caller), 101);
        vm.startPrank(caller);
        uint256 startGas = gasleft();
        ogMemecoin.transferFrom(address(this), address(target), 100);
        emit log_named_uint("OG TransferFrom: gas used", startGas - gasleft());
        startGas = gasleft();
        soladyMemecoin.transferFrom(address(this), address(target), 100);
        emit log_named_uint("TransferFrom: gas used", startGas - gasleft());
    }
}
