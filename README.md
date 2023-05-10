# MemeFactory

An ERC20 token factory for MemeCoins, with baseline token gas optimizations from [Solady](https://github.com/Vectorized/solady) and bespoke assembly on top to make new features as cheap as possible.

Based on [0xQuit's implementation](https://etherscan.io/address/0x3e9491cb1337b9f5322af7f5a5e431383b282076#code) outlined in [this Twitter thread](https://twitter.com/0xQuit/status/1655446206053752833).

# Features

- Commit-reveal scheme so your token name and address can't be front-run
  - Tokens with the same name can still be deployed, but only after committing to a (different) set of initialization params/salt and waiting out the commitment period
- Compared to 0xQuit's implementation, deploys are 20-25% more expensive, but
- Token methods are around 8% cheaper
  - The additional gas to deploy is offset after only 200 total on-chain token interactions – approvals, transfers, balance checks, etc.



# Usage

- commit a hash of your token name and given salt
  - you can call `computeCommittmentHash(string name, bytes32 salt)`, with the caveat that you will be exposing your request to the RPC provider
- wait longer than 1 minute, but shorter than 1 day
- call `deployMeme` with relevant parameters and the salt you used to commit

# Audits

lol, lmao