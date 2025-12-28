# Hoodi DAO Governance (Foundry)

Foundry-based project for a simple ERC20-governed DAO. Includes proposal creation, weighted voting, quorum enforcement, and a vote duration guard. Below are the essentials for running, testing, and deploying.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed (`foundryup`).
- Node optional (only if you need scripts that use npm).
- Access to a Hoodi-compatible RPC endpoint.

## Environment Variables

Copy `.env.example` to `.env` and fill:

```
PRIVATE_KEY=0xabc123...        # deployer key with funds
ETHERSCAN_API_KEY=your_key     # Hoodi explorer key for verification
GOVERNANCE_TOKEN_ADDRESS=0x... # ERC20 used for voting power
```

`PRIVATE_KEY` is only used locally when broadcasting/verification. Never commit `.env`.

## Install deps

```bash
forge install
```

## Build

```bash
forge build
```

## Test

```bash
forge test
```

## Deployment (broadcast)

1. Update `script/DaoDeploy.s.sol` with constructor args if needed (token/vote duration).
2. Run:

```bash
forge script script/DaoDeploy.s.sol:DaoScript \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

Optional flags:
- `--slow` to review txs before sending.
- `--legacy` if RPC doesn’t support EIP-1559.

Deployment outputs go to `broadcast/`.

## Verification only

If you deployed without `--verify`, run:

```bash
forge verify-contract \
  <DEPLOYED_ADDRESS> \
  src/DaoContract.c.sol:DaoContract \
  --constructor-args $(cast abi-encode "constructor(address,uint256)" $GOVERNANCE_TOKEN_ADDRESS $VOTE_DURATION) \
  --rpc-url $RPC_URL \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

Replace `$VOTE_DURATION` with seconds (e.g., `604800` for 7 days).

## Project structure

- `src/DaoContract.c.sol` – DAO contract (proposal/vote/execute).
- `script/` – deployment scripts (`forge script` entry points).
- `test/DaoTest.t.sol` – Forge tests (covers quorum and vote duration).
- `lib/` – installed dependencies (forge-std, OpenZeppelin).

## Useful commands

- `forge fmt` – format contracts.
- `forge snapshot` – gas report.
- `anvil` – local dev chain.
- `cast call`/`cast send` – quick RPC interactions.

## Notes

- Vote duration is enforced on-chain; execution reverts if window hasn’t elapsed.
- Governance token address must implement `balanceOf` compatible with ERC20.
- Adjust `quorumBps` or `voteDuration` in `DaoContract` constructor as needed before deployment.
