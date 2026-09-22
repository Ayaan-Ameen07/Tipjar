# TipJar

A minimal Solidity tip jar: anyone can `deposit()` ETH, per-address and
contract-wide totals are tracked on-chain, and only the owner can `withdraw()`.
Built with [Foundry](https://book.getfoundry.sh/) and
[OpenZeppelin Contracts v5](https://docs.openzeppelin.com/contracts/5.x/).

## Contract

See [`src/TipJar.sol`](src/TipJar.sol).

- `deposit()` — payable, reverts on `msg.value == 0`, accumulates per-address
  and contract-wide totals, emits `Tipped(from, amount, newTotal)`.
- `totalTipped(address)` — running total tipped by that address (auto-generated
  getter for the public mapping).
- `totalReceived()` — lifetime total ever received by the contract (auto-generated
  getter for a public counter; does **not** decrease on withdrawal).
- `withdraw()` — `onlyOwner`, sends the full current balance to the owner.
- `receive()` — a plain ETH transfer (no calldata) is also treated as a tip.

## Setup

```bash
forge install
forge build
forge test -vv
```

12 tests in [`test/TipJar.t.sol`](test/TipJar.t.sol) cover: ownership, single
and repeated deposits from the same address, independent tracking across
multiple addresses, the zero-value revert, the `Tipped` event payload, the
`receive()` fallback, withdrawal draining the balance without resetting
lifetime totals, the owner-only guard on `withdraw()`, the revert when there's
nothing to withdraw, and a 256-run fuzz test on accumulation math.

## Deploying to Sepolia

### 1. Get a Sepolia RPC URL

No signup needed — the default in `.env.example` is a free public endpoint
(`https://ethereum-sepolia-rpc.publicnode.com`). For more reliability you can
swap in a free [Alchemy](https://www.alchemy.com/) or [Infura](https://infura.io/)
Sepolia URL instead.

### 2. Get an Etherscan API key

Sign up at [etherscan.io](https://etherscan.io/), then create a free key at
[etherscan.io/myapikey](https://etherscan.io/myapikey). Used only for source
verification.

### 3. Create a deployer wallet (encrypted, local — never pasted into chat)

Use a **fresh burner wallet**, not one holding real funds. Foundry can
generate one and encrypt it on disk under `~/.foundry/keystores`, protected
by a password only you type:

```bash
cast wallet new
```

This prints a new address and private key **to your own terminal only**.
Copy the private key, then import it into an encrypted keystore (you'll be
prompted to paste the key and set a password):

```bash
cast wallet import tipjar-deployer --interactive
```

From then on you refer to it as `--account tipjar-deployer` — the raw key is
never needed again and never touches a file in this repo.

### 4. Fund it with Sepolia test ETH

Grab free Sepolia ETH from a faucet for the address `cast wallet new` printed:

- https://cloud.google.com/application/web3/faucet/ethereum/sepolia
- https://www.alchemy.com/faucets/ethereum-sepolia
- https://sepoliafaucet.com/

### 5. Configure `.env`

```bash
cp .env.example .env
```

Fill in `ETHERSCAN_API_KEY` (and swap `SEPOLIA_RPC_URL` if you're using your
own provider instead of the public default).

### 6. Deploy + verify

```bash
source .env
forge script script/DeployTipJar.s.sol \
  --rpc-url sepolia \
  --account tipjar-deployer \
  --broadcast \
  --verify \
  -vvvv
```

You'll be prompted for the keystore password you set in step 3. This deploys
`TipJar` and verifies its source on Sepolia Etherscan in one step. Note the
deployed contract address from the output (also saved to
`broadcast/DeployTipJar.s.sol/11155111/run-latest.json`).

If `--verify` fails to pick up an Etherscan confirmation in time (it can be
slow), verify separately:

```bash
forge verify-contract <CONTRACT_ADDRESS> src/TipJar.sol:TipJar --chain sepolia
```

### 7. Generate on-chain activity

Two deposits from the same address, then a withdrawal, so there's real
history to inspect on Etherscan:

```bash
export TIPJAR=<CONTRACT_ADDRESS>

cast send $TIPJAR "deposit()" --value 0.001ether \
  --rpc-url sepolia --account tipjar-deployer

cast send $TIPJAR "deposit()" --value 0.002ether \
  --rpc-url sepolia --account tipjar-deployer

cast send $TIPJAR "withdraw()" \
  --rpc-url sepolia --account tipjar-deployer
```

Sanity-check the on-chain state read-only:

```bash
cast call $TIPJAR "totalTipped(address)(uint256)" $(cast wallet address --account tipjar-deployer) --rpc-url sepolia
cast call $TIPJAR "totalReceived()(uint256)" --rpc-url sepolia
```

## Design notes

- **OpenZeppelin v5 `Ownable`** requires an explicit initial owner in the
  constructor (`Ownable(msg.sender)`) — v5 removed the implicit
  `msg.sender`-as-owner default from v4.
- **`totalReceived` is a lifetime counter, not `address(this).balance`.** It's
  tracked explicitly and never decremented on withdrawal, so it keeps
  answering "how much has this jar ever received" even after funds leave —
  consistent with `totalTipped` also being cumulative per address.
- **`withdraw()` uses `.call{value: balance}("")`** rather than `.transfer()`,
  since `.transfer()`'s hard-coded 2300 gas stipend can break if the owner is
  ever a smart-contract wallet. `balance` is read before the external call
  (checks-effects-interactions).
- **No `ReentrancyGuard`.** `withdraw()` is `onlyOwner` and only ever pays the
  owner, so the only party who could exploit reentrancy here is the owner
  exploiting themselves — the extra dependency wasn't worth adding.
- **`receive()` mirrors `deposit()`** so a plain ETH transfer to the contract
  address (not just an explicit `deposit()` call) is still tracked and emits
  `Tipped`, instead of silently reverting.

## Testing

`forge test -vv` — 12 tests, including a fuzz test, all passing. Deployment
itself was exercised end-to-end on Sepolia: two deposits from the same
deployer address followed by one `withdraw()`, matching the "real activity"
requirement.
