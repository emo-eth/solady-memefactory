// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract CommitReveal {
    error InvalidCommitment();

    uint256 constant INVALID_COMMITMENT_SELECTOR = 0xc06789fa;
    uint256 public constant COMMITMENT_LIFESPAN = 1 days;
    uint256 public constant COMMITMENT_PERIOD = 1 minutes;

    mapping(address committer => mapping(bytes32 commitmentHash => uint256 timestamp)) internal _commitments;

    function commit(bytes32 commitmentHash) external {
        ///@solidity memory-safe-assembly
        assembly {
            mstore(0, caller())
            mstore(0x20, _commitments.slot)
            let nestedMapSlot := keccak256(0, 0x40)
            mstore(0, commitmentHash)
            mstore(0x20, nestedMapSlot)
            let finalSlot := keccak256(0, 0x40)
            sstore(finalSlot, timestamp())
        }
    }

    function calculateCommitmentHash(string calldata name, bytes32 salt) external pure returns (bytes32 result) {
        ///@solidity memory-safe-assembly
        assembly {
            mstore(0, salt)
            let loaded := calldataload(name.offset)
            let numShiftBits := sub(256, shl(3, name.length))
            let cleaned := shl(numShiftBits, shr(numShiftBits, loaded))
            mstore(0x20, cleaned)
            result := keccak256(0, 0x40)
            mstore(0, result)
            return(0, 0x20)
        }
    }

    function getCommitment(address committer, bytes32 commitmentHash) public view returns (uint256 _timestamp) {
        ///@solidity memory-safe-assembly
        assembly {
            mstore(0, committer)
            mstore(0x20, _commitments.slot)
            let nestedMapSlot := keccak256(0, 0x40)
            mstore(0, commitmentHash)
            mstore(0x20, nestedMapSlot)
            let finalSlot := keccak256(0, 0x40)
            _timestamp := sload(finalSlot)
        }
    }

    function _validateCommitment(bytes32 salt, string calldata name) internal view {
        bytes32 computedHash;
        ///@solidity memory-safe-assembly
        assembly {
            mstore(0, salt)
            let loaded := calldataload(name.offset)
            let numShiftBits := sub(256, shl(3, name.length))
            let cleaned := shl(numShiftBits, shr(numShiftBits, loaded))
            mstore(0x20, cleaned)
            computedHash := keccak256(0, 0x40)
        }
        uint256 committedTimestamp = getCommitment(msg.sender, computedHash);
        ///@solidity memory-safe-assembly
        assembly {
            let errBuffer := gt(sub(timestamp(), committedTimestamp), COMMITMENT_LIFESPAN)
            errBuffer := or(errBuffer, lt(sub(timestamp(), committedTimestamp), COMMITMENT_PERIOD))
            if errBuffer {
                mstore(0, INVALID_COMMITMENT_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
    }
}
