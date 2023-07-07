## State Expiry Proof-of-Concept

State Expiry is a mechanism to remove expired data from the blockchain temporarily. Expired data can no longer be accessed temporarily, unless it is revived through an operation called "state revive". By implementing State Expiry, we are able to tackle the state bloat problem, reducing the storage requirements to run a node over the long run.

This repository contains the setup guide to test the State Expiry Proof-of-Concept (PoC) implemented by the NodeReal development team. The POC is based on [BEP-206](https://github.com/setunapo/BEPs/blob/bep205_state_expiry/BEP206.md) and [BEP-215](https://github.com/bnb-chain/BEPs/pull/215).

## ⚙️ Installation

### Prerequisites

- Golang 1.19 or higher
- nodeJS 18 or higher

### Environment Setup

1. Clone repo and submodules.

```bash
git clone --recursive https://github.com/node-real/state-expiry-poc.git
```

2. Prepare state expiry binary, and clone BSC repo with `state_expiry_develop` branch.

```bash
git clone https://github.com/node-real/bsc --branch state_expiry_develop bsc-state-expiry
```

3. Compile `geth` and `bootnode`, then copy to `bin` folder

```bash
cd bsc-state-expiry
make geth && go build -o bootnode ./cmd/bootnode
mkdir -p ../state-expiry-poc/bin && cp build/bin/geth bootnode ../state-expiry-poc/bin
```

## 🤖 Testing Flow

The complete flow of testing the state expiry features may look something like:

1. Deploy nodes
2. Deploy token contract
3. Read token balance
4. Wait for contract state to be expired
5. Read token balance again (expired error is returned)
6. Send revive transaction to revive contract state
7. Read token balance
8. Stop nodes

When a contract is deployed, you should wait for 2 epochs (100 blocks) so that its state is expired. Here's the table reference:

| Epoch | Block Number (Decimal) | Block Number (Hex) |
| ----- | ---------------------- | ------------------ |
| 0     | 0                      | 0x0                |
| 1     | 50                     | 0x32               |
| 2     | 100                    | 0x64               |
| 3     | 150                    | 0x96               |

## 💻 Commands

Now, we need enter `state-expiry-poc` to run testing.

```bash
cd state-expiry-poc
```

### Run state expiry client

All setup scripts in `state-expiry-poc/scripts`, it will set up default 3 nodes config, and start them.

#### Deploy 3 archive nodes

```bash
# Deploying 3 archive nodes
# modifies the genesis such that the first account of scripts/asset/test_account.json is the initBnbHolder
bash scripts/clusterup_set_first.sh start
```

#### Deploy 2 full node + 1 archive node

```bash
bash scripts/clusterup_pruning_test.sh start
```

#### Stop cluster nodes

```bash
bash scripts/clusterup_set_first.sh stop
```

### Deploy BEP20 & Testing

Then enter `state-expiry-poc/test-contract/deploy-BEP20` to run all BEP20 scripts.

It mock a fake BEP20 token to test contract slots expiry scenarios.

```bash
cd test-contract/deploy-BEP20
```

#### Deploy BEP20 Token Contract

```bash
# install dependencies
npm install
# deploy BEP20 Token
npx hardhat run scripts/deploy.js
```

#### Transfer BEP20 Token & Read Balance

```bash
# This will transfer BEP20 Token from scripts/asset/test_account.json first account
# This script only transfer once
npx hardhat run scripts/transfer.js
# read sender & receiver's balance
npx hardhat run scripts/read-balance.js
```

Now, you could use default users to `transfer` tokens, but when you stop using on-chain interactions after a period of time, `readBalance` only works because it doesn't trigger on-chain state access.

In the default config, after about 20 minutes, you cannot directly use the script to `transfer` tokens, may get `Access expired state` error. 

In this case, you need to revive state. For details, see `test test_bep20_witness_revive`.

### Other testcases

Then enter `state-expiry-poc/test-script` to run all golang scripts.

```bash
cd test-script
```

#### BNB transfer Loop

```bash
# The script keeps sending transactions until ctrl-c
go run test_bnb_transfer.go
```

#### Send revive transaction

When you BEP20 token got `Access expired state` error, you should call below script to revive you tx's accessed states. 

It will call `eth_estimateGasAndReviveState` API first and got revive `Witness`, then it will send a `ReviveStateTx` with `Witness` to revive all your expired states, and execute the tx as normal.

```bash
# The script will revive sender & receiver state, and exe a new token transfer
go run test_bep20_witness_revive.go
```

### Useful RPC Commands

```bash
# query block height
curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":83}' 127.0.0.1:8502

# query block by number
curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x3", true],"id":83}' 127.0.0.1:8502

# query tx by hash
curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"eth_getTransactionByHash","params":["0x12beecfb1adb7d874c4714a7871e23cf70baef612235d1276568611460927f18"],"id":83}' 127.0.0.1:8502

# query tx receipt
curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0x782192568c8ee3393e3f3e9b7ac46e231d3cbe0b96941b642e28220ba343209b"],"id":83}' 127.0.0.1:8502
```
## 📝 Config

The default genesis config is shown below:

```json
{
  "config": {
    "chainId": 714,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "muirGlacierBlock": 0,
    "ramanujanBlock": 0,
    "nielsBlock": 0,
    "mirrorSyncBlock":1,
    "brunoBlock": 1,
    "eulerBlock": 2,
    "gibbsBlock": 3,
    "moranBlock": 4,
    "planckBlock": 5,
    "lubanBlock": 6,
    "platoBlock": 7,
    "claudeBlock": 200,
    "elwoodBlock": 400,
    "parlia": {
      "period": 3,
      "epoch": 200,
      "stateEpochPeriod": 10
    }
  }
}
```

The default EpochPeriod is 200, the state will expired in the next 2 epoch, so it will expired in max 20 minutes. `claudeBlock` is the first hard fork for state expiry, `elwoodBlock` is the second hard fork and `parlia.epoch` is the EpochPeriod.
