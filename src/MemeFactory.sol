// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Memecoin} from "./Memecoin.sol";
import {CommitReveal} from "./CommitReveal.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract MemeFactory is CommitReveal {
    error FailedToInitialize();
    error TeamAllocationTooHIgh();
    error MustProvideLiquidity();

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
            let loaded := calldataload(sub(name.offset, 1))
            let numShiftBits := sub(256, shl(3, name.length))
            let cleaned := shl(numShiftBits, shr(numShiftBits, loaded))
            salt := cleaned
        }
        Memecoin meme =
        new Memecoin{salt: salt, value: msg.value}(name, sym, totalSupply * 1e18, msg.sender, teamBps, liquidityLockPeriodInSeconds);
        if (teamBps < 10000) {
            ///@solidity memory-safe-assembly
            assembly {
                let success := call(gas(), meme, 0, 0, 0, 0, 0)
                if iszero(success) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }
        return address(meme);
    }
}
