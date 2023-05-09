// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ERC20} from "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {IUniswapV2Factory} from "./interface/IUniswapV2Factory.sol";
import {IUniswapV2Router} from "./interface/IUniswapV2Router.sol";

contract Memecoin is ERC20, Ownable {
    error FailedToProvideLiquidity();
    error CallerNotOwner();
    error LiquidityLocked();
    error InvalidInitializationParams();

    uint256 private constant ADD_LIQUIDITY_ETH_SELECTOR = 0xf305d719;
    uint256 private constant GET_PAIR_SELECTOR = 0xe6a43905;
    uint256 private constant BALANCE_OF_SELECTOR = 0x70a08231;
    uint256 private constant TRANSFER_SELECTOR = 0xa9059cbb;
    uint256 private constant INVALID_INITIALIZATION_PARAMS_SELECTOR = 0x7676b397;
    uint256 private constant LIQUIDITY_LOCKED_SELECTOR = 0x8f4e75b2;

    address private constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 public immutable TEAM_BPS;
    uint256 public immutable LIQUIDITY_LOCKED_UNTIL;
    address public immutable UNISWAP_PAIR;

    bytes32 immutable _NAME;
    bytes32 immutable _SYMBOL;

    constructor(
        string memory name_,
        string memory sym,
        uint256 _totalSupply,
        address _deployer,
        uint256 _teamBps,
        uint256 liquidityLockPeriodInSeconds
    ) payable {
        bytes32 _name;
        bytes32 _symbol;
        uint256 liquidityLockedUntil;
        ///@solidity memory-safe-assembly
        assembly {
            let nameLen := mload(name_)
            let symLen := mload(sym)
            // team bps cannot be greater than 10000
            let errBuffer := gt(_teamBps, 10000)
            // if msg.value is 0, then team bps must be 10000
            errBuffer := or(errBuffer, and(iszero(callvalue()), lt(_teamBps, 10000)))
            // name must be shorter than 32 bytes but longer than 0 bytes
            errBuffer := or(errBuffer, or(iszero(nameLen), gt(nameLen, 31)))
            // symbol must be shorter than 32 bytes but longer than 0 bytes
            errBuffer := or(errBuffer, or(iszero(symLen), gt(symLen, 31)))
            // assert error buffer is zero
            if errBuffer {
                mstore(0, INVALID_INITIALIZATION_PARAMS_SELECTOR)
                revert(0x1c, 0x04)
            }
            // load the last byte encoding length of each string plus the next 31 bytes
            _name := mload(add(31, name_))
            _symbol := mload(add(31, sym))
            // add timestamp to liquidity lock period
            liquidityLockedUntil := add(timestamp(), liquidityLockPeriodInSeconds)
        }

        // assign owner
        _setOwner(_deployer);

        // calculate team and pool tokens
        uint256 teamTokens;
        uint256 poolTokens;
        ///@solidity memory-safe-assembly
        assembly {
            let fullTotalSupply := mul(_totalSupply, 1000000000000000000)
            teamTokens := div(mul(fullTotalSupply, _teamBps), 10000)
            poolTokens := sub(fullTotalSupply, teamTokens)
        }

        // mint team tokens to deployer
        _mint(_deployer, teamTokens);
        // declare pair temp variable
        address pair;

        // pool if poolTokens > 0
        if (poolTokens > 0) {
            // mint tokens for pool to this contract
            _mint(address(this), poolTokens);
            // approve uniswap router to spend pool tokens
            _approve(address(this), UNISWAP_ROUTER, poolTokens);
            //@solidity memory-safe-assembly
            assembly {
                function checkSuccess(status) {
                    // check if call was successful and bubble up error if not
                    if iszero(status) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                }

                // load and pre-emptively update free memory pointer
                let freePtr := mload(0x40)
                mstore(0x40, add(0x140, freePtr))
                // store selector
                mstore(freePtr, ADD_LIQUIDITY_ETH_SELECTOR)
                // store token
                mstore(add(freePtr, 0x20), address())
                // store amountTokenDesired
                mstore(add(freePtr, 0x40), poolTokens)
                // (don't) store amountTokenMin
                // mstore(add(freePtr, 0x60), 0)
                // (don't) store amountEthMin
                // mstore(add(freePtr, 0x80), 0)
                // store to
                mstore(add(freePtr, 0x100), address())
                // store deadline
                mstore(add(freePtr, 0x120), timestamp())
                // perform call to pool and forward msg.value
                checkSuccess(call(gas(), UNISWAP_ROUTER, callvalue(), add(freePtr, 0x1c), 0x124, 0, 0))

                // get pair address
                mstore(0, GET_PAIR_SELECTOR)
                mstore(0x20, address())
                mstore(0x40, WETH)
                checkSuccess(call(gas(), UNISWAP_FACTORY, 0, 0x1c, 0x44, 0, 0x20))
                pair := mload(0)
            }
        }

        // assign immutables
        _NAME = _name;
        _SYMBOL = _symbol;
        TEAM_BPS = _teamBps;
        LIQUIDITY_LOCKED_UNTIL = liquidityLockedUntil;
        UNISWAP_PAIR = pair; // may be address(0) if poolTokens == 0, and cannot be changed
    }

    function name() public view override returns (string memory _name) {
        bytes32 name_ = _NAME;
        ///@solidity memory-safe-assembly
        assembly {
            // get the free memory pointer
            let freePtr := mload(0x40)
            // set _name to the free memory pointer
            _name := freePtr
            // update free pointer by two words
            mstore(0x40, add(0x40, freePtr))
            // write the length of the name to the last byte of the first word
            // and the contents to the next word
            mstore(add(_name, 0x1f), name_)
        }
    }

    function symbol() public view override returns (string memory _symbol) {
        bytes32 symbol_ = _SYMBOL;
        ///@solidity memory-safe-assembly
        assembly {
            let freePtr := mload(0x40)
            _symbol := freePtr
            // update free pointer by two words
            mstore(0x40, add(0x40, freePtr))
            // write the length of the symbol to the last byte of the first word
            // and the contents to the next word
            mstore(add(_symbol, 0x1f), symbol_)
        }
    }

    function withdrawLP() external onlyOwner {
        // place immutable onto stack
        uint256 liquidityLockedUntil = LIQUIDITY_LOCKED_UNTIL;
        address pair = UNISWAP_PAIR;
        // place owner onto stack
        address owner = owner();
        ///@solidity memory-safe-assembly
        assembly {
            function checkSuccess(status) {
                // check if call was successful and bubble up error if not
                if iszero(status) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }

            // assert liquidity is unlocked
            if gt(liquidityLockedUntil, timestamp()) {
                mstore(0, LIQUIDITY_LOCKED_SELECTOR)
                revert(0x1c, 0x04)
            }
            // cache free memory ptr
            let freePtr := mload(0x40)

            // get LP token balance
            mstore(0, BALANCE_OF_SELECTOR)
            checkSuccess(call(gas(), pair, 0, 0x1c, 0x24, 0, 0x20))
            let tokenBalance := mload(0)

            // transfer tokens to owner
            mstore(0, TRANSFER_SELECTOR)
            mstore(0x20, owner)
            mstore(0x40, tokenBalance)
            checkSuccess(call(gas(), pair, 0, 0x1c, 0x44, 0, 0))

            // restore free memory ptr since block is declared memory-safe I guess
            mstore(0x40, freePtr)
        }
    }
}
