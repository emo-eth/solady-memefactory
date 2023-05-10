// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Memecoin} from "./Memecoin.sol";
import {CommitReveal} from "./CommitReveal.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract MemeFactory is CommitReveal {
    function deployMeme(
        string calldata name,
        string calldata sym,
        uint256 totalSupply,
        uint256 teamBps,
        uint256 liquidityLockPeriodInSeconds,
        bytes32 salt
    ) external payable returns (address) {
        // validate the deployer has committed to the name+salt combo
        _validateCommitment(salt, name);

        // re-use validation for deploy salt – allows for vanity addresses
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
        ///@solidity memory-safe-assembly
        assembly {
            mstore(0, meme)
            return(0, 0x20)
        }
    }
}
