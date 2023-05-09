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
        ///@solidity memory-safe-assembly
        assembly {
            let errBuffer := iszero(lt(_teamBps, 10000))

            errBuffer := or(errBuffer, gt(mload(name_), 31))
            errBuffer := or(errBuffer, gt(mload(sym), 31))
            if errBuffer {
                mstore(0, INVALID_INITIALIZATION_PARAMS_SELECTOR)
                revert(0x1c, 0x20)
            }
            _name := mload(add(31, name_))
            _symbol := mload(add(31, sym))
        }
        _NAME = _name;
        _SYMBOL = _symbol;

        TEAM_BPS = _teamBps;
        LIQUIDITY_LOCKED_UNTIL = block.timestamp + liquidityLockPeriodInSeconds;
        _setOwner(_deployer);

        uint256 teamTokens; // = (fullTotalSupply * TEAM_BPS) / 100;
        uint256 poolTokens; //= fullTotalSupply - teamTokens;
        ///@solidity memory-safe-assembly
        assembly {
            let fullTotalSupply := mul(_totalSupply, 1000000000000000000)
            teamTokens := div(mul(fullTotalSupply, _teamBps), 10000)
            poolTokens := sub(fullTotalSupply, teamTokens)
        }

        // _mint(_deployer, teamTokens);
        // _mint(address(this), poolTokens);
        // _approve(address(this), UNISWAP_ROUTER, poolTokens);

        if (poolTokens > 0) {
            (bool success,) = UNISWAP_ROUTER.call{value: msg.value}(
                abi.encodeCall(
                    IUniswapV2Router.addLiquidityETH, (address(this), poolTokens, 0, 0, address(this), block.timestamp)
                )
            );

            if (!success) revert FailedToProvideLiquidity();
        }
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
        uint256 liquidityLockedUntil;
        address owner = owner();
        ///@solidity memory-safe-assembly
        assembly {
            function checkSuccess(status) {
                if iszero(status) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }

            // assert liquidity is unlocked
            if gt(liquidityLockedUntil, timestamp()) {
                mstore(0, LIQUIDITY_LOCKED_SELECTOR)
                revert(0x1c, 0x20)
            }
            // cache free memory ptr
            let freePtr := mload(0x40)

            // get pair address
            mstore(0, GET_PAIR_SELECTOR)
            mstore(0x20, address())
            mstore(0x40, WETH)
            checkSuccess(call(gas(), UNISWAP_FACTORY, 0, 0x1c, 0x44, freePtr, 0x20))
            let pair := mload(freePtr)

            // get LP token balance
            mstore(0, BALANCE_OF_SELECTOR)
            checkSuccess(call(gas(), pair, 0, 0x1c, 0x24, freePtr, 0x20))
            let tokenBalance := mload(freePtr)

            // transfer tokens to owner
            mstore(0, TRANSFER_SELECTOR)
            mstore(0x20, owner)
            mstore(0x40, tokenBalance)
            checkSuccess(call(gas(), pair, 0, 0x1c, 0x44, 0, 0))
        }
    }
}
