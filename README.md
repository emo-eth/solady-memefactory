# MemeCoinFactory

Gas-optimized ERC20 token factory for MemeCoins. Based on [0xQuit's implementation](https://etherscan.io/address/0x3e9491cb1337b9f5322af7f5a5e431383b282076#code) outlined in [this Twitter thread](https://twitter.com/0xQuit/status/1655446206053752833).

# Features

- Commit-reveal scheme so your token name can't be front-run
- Deploys are 20% more expensive, but
- Token methods are around 8% cheaper
  - The additional gas to deploy is offset after only 200 total on-chain token interactions – approvals, transfers, balance checks, etc.