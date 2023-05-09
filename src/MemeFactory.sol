// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Memecoin} from "./Memecoin.sol";
import {CommitReveal} from "./CommitReveal.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract MemeFactory is CommitReveal {
    error FailedToInitialize();
    error TeamAllocationTooHIgh();
    error MustProvideLiquidity();

    constructor() {
        // Memecoin memecoin = new Memecoin();
    }

    function deployMeme(
        string calldata name,
        string calldata sym,
        uint256 totalSupply,
        uint256 teamBps,
        uint256 liquidityLockPeriodInSeconds,
        bytes32 commitmentSalt
    ) external payable returns (address) {
        // validate the deployer has committed to the name
        _validateCommitment(commitmentSalt, name);

        // use the name as the salt for the deploy
        bytes32 salt;
        ///@solidity memory-safe-assembly
        assembly {
            salt := calldataload(name.offset)
        }
        Memecoin meme =
        new Memecoin{salt: salt, value: msg.value}(name, sym, totalSupply, msg.sender, teamBps, liquidityLockPeriodInSeconds);
        return address(meme);
    }
}
