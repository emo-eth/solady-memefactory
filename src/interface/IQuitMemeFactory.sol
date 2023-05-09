pragma solidity ^0.8.10;

interface IQuitMemeFactory {
    function deployMeme(
        string memory name,
        string memory sym,
        uint256 totalSupply,
        uint256 teamPercentage,
        uint256 liquidityLockPeriodInSeconds
    ) external payable returns (address tokenAddress);
    function implementation() external view returns (address);
}
